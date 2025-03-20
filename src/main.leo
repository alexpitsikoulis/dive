import credits.aleo;

program dive_v0_1_0.aleo {
    struct Event {
        // Unique identifier for the event.
        id: field,
        // Initial supply of tickets.
        initial_supply: u32,
        // Available supply of tickets.
        ticket_supply: u32,
        // Number of sold tickets which have been redeemed.
        redeemed_tickets: u32,
        // Price per ticket in microcredits.
        ticket_price: u64,
        // Boolean value denoting whether or not the event has ended.
        is_ended: bool,
        // Boolean value denoting whether or not a refund has been issued.
        is_refunded: bool,
        // Owner of the event who will receive payment for purchased tickets.
        event_owner: address,
    }

    // Record of an event id an owner has tickets for, to be hashed as the key in the `user_tickets` mapping.
    struct TicketHolder {
        addr: address,
        event_id: field,
    }

    // Mapping of events by id.
    mapping events: field => Event;
    // Mapping of hash(address, event_id) => number of tickets held by the account.
    mapping user_tickets: field => u32;
    // Mapping of event owner addresses to the sums they are owed.
    mapping payouts: address => u64;


    // Create a hash of the record of the owner address and the id for the event they have tickets for.
    inline hash_ticket_holder(ticket_owner: address, event_id: field) -> field {
        let ticket_holder: TicketHolder = TicketHolder {
            addr: ticket_owner,
            event_id,
        };
        return BHP256::hash_to_field(ticket_holder);
    }


    // Initialize an event and add it to the `events` mapping.
    async transition register_event(
        id: field,
        ticket_supply: u32,
        ticket_price: u64,
    ) -> Future {
        let event: Event = Event {
            id,
            initial_supply: ticket_supply,
            ticket_supply,
            ticket_price,
            redeemed_tickets: 0u32,
            is_ended: false,
            is_refunded: false,
            event_owner: self.caller,
        };
        return finalize_register_event(event);
    }

    async function finalize_register_event(event: Event) {
        // Ensure the event does not already exist in the mapping.
        assert(!events.contains(event.id));
        events.set(event.id, event);
        if !payouts.contains(event.event_owner) {
            payouts.set(event.event_owner, 0u64);
        }
    }


    // Increase the ticket supply for an event.
    async transition add_tickets(event_id: field, num_tickets: u32) -> Future {
        return finalize_add_tickets(self.caller, event_id, num_tickets);
    }

    async function finalize_add_tickets(caller: address, event_id: field, num_tickets: u32) {
        let event: Event = events.get(event_id);
        // Ensure the transition was called by the event owner.
        assert_eq(caller, event.event_owner);
        // Ensure the event has not ended or been refunded.
        assert(!event.is_ended && !event.is_refunded);
        let updated_event: Event = Event {
            id: event_id,
            initial_supply: event.initial_supply + num_tickets,
            ticket_supply: event.ticket_supply + num_tickets,
            ticket_price: event.ticket_price,
            redeemed_tickets: event.redeemed_tickets,
            is_ended: false,
            is_refunded: false,
            event_owner: event.event_owner,
        };
        events.set(event_id, updated_event);
    }

    // End the event, preventing further ticket sales and redemption.
    // If more than half of the sold tickets were redeemed then the event owner receives the remainder of their escrow balance.
    async transition end_event(private event_id: field) -> Future {
        return finalize_end_event(event_id);
    }

    async function finalize_end_event(event_id: field) {
        let event: Event = events.get(event_id);
        let tickets_sold: u32 = event.initial_supply - event.ticket_supply;
        // Ensure the event has not already been ended or refunded.
        assert(!event.is_ended && !event.is_refunded);
        if event.redeemed_tickets * 2u32 >= tickets_sold {
            // pay out owed balance to event owner
            let updated_event: Event = Event {
                id: event_id,
                initial_supply: event.initial_supply,
                ticket_supply: event.ticket_supply, // should this change to 0?
                ticket_price: event.ticket_price,
                redeemed_tickets: event.redeemed_tickets,
                is_ended: true,
                is_refunded: false,
                event_owner: event.event_owner,
            };
            events.set(event_id, updated_event);
        } else {
            // issue refund
            let updated_event: Event = Event {
                id: event_id,
                initial_supply: event.initial_supply,
                ticket_supply: event.ticket_supply, // should this change to 0?
                ticket_price: event.ticket_price,
                redeemed_tickets: event.redeemed_tickets,
                is_ended: true,
                is_refunded: true,
                event_owner: event.event_owner,
            };
            events.set(event_id, updated_event);
        }
    }


    // Cancel event and open it up to refunds.
    async transition refund_event(private event_id: field) -> Future {
        return finalize_refund_event(event_id);
    }

    async function finalize_refund_event(event_id: field) {
        let event: Event = events.get(event_id);
        // Ensure the event has not already been ended or refunded.
        assert(!event.is_ended && !event.is_refunded);

        let updated_event: Event = Event {
            id: event_id,
            initial_supply: event.initial_supply,
            ticket_supply: event.ticket_supply,
            ticket_price: event.ticket_price,
            redeemed_tickets: event.redeemed_tickets,
            is_ended: true,
            is_refunded: true,
            event_owner: event.event_owner,
        };
        events.set(event_id, updated_event);
    }


    // Buy tickets for an event.
    async transition buy_tickets(
        private event_id: field,
        private buyer_record: credits.aleo/credits,
        public num_tickets: u32,
        public ticket_price: u64,
        public event_owner: address,
    ) -> (credits.aleo/credits, Future) {
        // Ensure the record belongs to the caller.
        assert_eq(self.caller, buyer_record.owner);
        let ticket_holder_hash: field = hash_ticket_holder(self.caller, event_id);
        let total_cost: u64 = num_tickets as u64 * ticket_price;

        let (change, fut): (credits.aleo/credits, Future) = credits.aleo/transfer_private_to_public(buyer_record, dive_v0_1_0.aleo, total_cost);
        
        return (change, finalize_buy_tickets(event_id, ticket_holder_hash, num_tickets, fut));
    }

    async function finalize_buy_tickets(
        event_id: field,
        ticket_holder: field,
        num_tickets: u32,
        transfer_fut: Future,
    ) {
        let event: Event = events.get(event_id);
        // Ensure there are enough tickets to fulfill the request.
        assert(event.ticket_supply.gte(num_tickets));
        // Ensure the event has not been ended or refunded.
        assert(!event.is_ended && !event.is_refunded);
        let total_cost: u64 = num_tickets as u64 * event.ticket_price;

        // Subtract the purchased tickets from the ticket supply.
        let updated_event: Event = Event {
            id: event_id,
            initial_supply: event.initial_supply,
            ticket_supply: event.ticket_supply - num_tickets,
            ticket_price: event.ticket_price,
            redeemed_tickets: event.redeemed_tickets,
            is_ended: event.is_ended,
            is_refunded: event.is_refunded,
            event_owner: event.event_owner,
        };
        events.set(event_id, updated_event);
        // If the purchaser already has tickets for this event then add the new tickets to their total
        // Otherwise initialize them in the mapping with the purchased tickets.
        if user_tickets.contains(ticket_holder) {
            let prev_tickets: u32 = user_tickets.get(ticket_holder);
            user_tickets.set(ticket_holder, prev_tickets + num_tickets);
        } else {
            user_tickets.set(ticket_holder, num_tickets);
        }

        // Add the total cost to the event owners' payout.
        let prev_payout: u64 = payouts.get(event.event_owner);
        payouts.set(event.event_owner, prev_payout + total_cost);

        transfer_fut.await();
    }


    // Transfer tickets to another account.
    async transition transfer_tickets(
        private event_id: field,
        private recipient: address,
        private num_tickets: u32,
        public current_time: u64,
    ) -> Future {
        let sender_hash: field = hash_ticket_holder(self.caller, event_id);
        let recipient_hash: field = hash_ticket_holder(recipient, event_id);

        return finalize_transfer_tickets(event_id, sender_hash, recipient_hash, num_tickets, current_time);
    }

    async function finalize_transfer_tickets(
        event_id: field,
        sender_hash: field,
        recipient_hash: field,
        num_tickets: u32,
        current_time: u64,
    ) {
        // Ensure the caller has enough tickets to fulfill the transfer.
        let sender_tickets: u32 = user_tickets.get(sender_hash);
        assert(sender_tickets.gte(num_tickets));

        let event: Event = events.get(event_id);
        // Ensure the event has not been ended or refunded.
        assert(!event.is_ended && !event.is_refunded);

        user_tickets.set(sender_hash, sender_tickets - num_tickets);
        
        // If the recipient already has tickets for this event then add the new tickets to their total
        // Otherwise initialize them in the mapping with the transferred tickets.
        if user_tickets.contains(recipient_hash) {
            let prev_tickets: u32 = user_tickets.get(recipient_hash);
            user_tickets.set(recipient_hash, prev_tickets + num_tickets);
        } else {
            user_tickets.set(recipient_hash, num_tickets);
        }
    }


    // Redeem tickets, to be used at point of entry.
    // Number of tickets to be redeemed may be a partial amount.
    async transition redeem_tickets(
        private event_id: field,
        private num_tickets: u32,
    ) -> Future {
        let ticket_holder_hash: field = hash_ticket_holder(self.caller, event_id);
        
        // pay event owner from program escrow
        
        return finalize_redeem_tickets(event_id, ticket_holder_hash, num_tickets);
    }

    async function finalize_redeem_tickets(event_id: field, ticket_holder_hash: field, num_tickets: u32) {
        // Ensure the user has at least as many tickets as they are trying to redeem. 
        let held_tickets: u32 = user_tickets.get(ticket_holder_hash);
        assert(held_tickets.gte(num_tickets));
        user_tickets.set(ticket_holder_hash, held_tickets - num_tickets);
        
        let event: Event = events.get(event_id);

        // Ensure the event has not been ended or refunded.
        assert(!event.is_ended && !event.is_refunded);

        let prev_redeemed: u32 = event.redeemed_tickets;
        let updated_event: Event = Event {
            id: event_id,
            initial_supply: event.initial_supply,
            ticket_supply: event.ticket_supply,
            redeemed_tickets: prev_redeemed + num_tickets,
            ticket_price: event.ticket_price,
            is_ended: event.is_ended,
            is_refunded: event.is_refunded,
            event_owner: event.event_owner,
        };
        events.set(event_id, updated_event);

        // await future for payment to event owner
    }


    // Claim refund for a canceled/refunded event
    async transition claim_refund(
        private event_id: field,
        private refundee_record: credits.aleo/credits,
    ) -> Future {
        let refundee: address = refundee_record.owner;
        let refundee_hash: field = hash_ticket_holder(refundee, event_id);
        return finalize_claim_refund(event_id, refundee_hash);
    }

    async function finalize_claim_refund(event_id: field, refundee_hash: field) {
        let num_tickets: u32 = user_tickets.get(refundee_hash);
        // Ensure the refundee has tickets for the event.
        assert(num_tickets.gte(1u32));
        let event: Event = events.get(event_id);
        // Ensure the event is refunded;
        assert(event.is_refunded);
        
        // refund user

        user_tickets.set(refundee_hash, 0u32);
    }
}
