import credits.aleo;

program dive_v0_1_0.aleo {
    struct Event {
        // Unique identifier for the event.
        id: field,
        // Available supply of tickets.
        ticket_supply: u32,
        // Price per ticket in microcredits.
        ticket_price: u64,
        // Owner of the event who will receive payment for purchased tickets.
        event_owner: address,
    }

    // Record of an event id an owner has tickets for, to be hashed as the key in the `user_tickets` mapping.
    record TicketHolder {
        owner: address,
        event_id: field,
    }

    // Mapping of events by id.
    mapping events: field => Event;
    // Mapping of hash(address, event_id) => number of tickets held by the account.
    mapping user_tickets: field => u32;


    // Create a hash of the record of the owner address and the id for the event they have tickets for.
    function hash_ticket_holder(ticket_owner: address, event_id: field) -> field {
        let ticket_holder: TicketHolder = TicketHolder {
            owner: ticket_owner,
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
            ticket_supply,
            ticket_price,
            event_owner: self.caller,
        };
        return finalize_register_event(event);
    }

    async function finalize_register_event(event: Event) {
        // Ensure the event does not already exist in the mapping.
        assert(!events.contains(event.id));
        events.set(event.id, event);
    }


    // Increase the ticket supply for an event.
    async transition add_tickets(event_id: field, num_tickets: u32) -> Future {
        return finalize_add_tickets(self.caller, event_id, num_tickets);
    }

    async function finalize_add_tickets(caller: address, event_id: field, num_tickets: u32) {
        let event: Event = events.get(event_id);
        // Ensure the transition was called by the event owner.
        assert_eq(caller, event.event_owner);
        let updated_event: Event = Event {
            id: event_id,
            ticket_supply: event.ticket_supply + num_tickets,
            ticket_price: event.ticket_price,
            event_owner: event.event_owner,
        };
        events.set(event_id, updated_event);
    }


    // Change the ticket price for an event.
    async transition update_price(event_id: field, new_price: u64) -> Future {
        return finalize_update_price(self.caller, event_id, new_price);
    }

    async function finalize_update_price(caller: address, event_id: field, new_price: u64) {
        let event: Event = events.get(event_id);
        // Ensure the transition was called by the event owner.
        assert_eq(caller, event.event_owner);
        let updated_event: Event = Event {
            id: event_id,
            ticket_supply: event.ticket_supply,
            ticket_price: new_price,
            event_owner: event.event_owner,
        };
        events.set(event_id, updated_event);
    }


    // Buy tickets for an event.
    async transition buy_tickets(
        private event_id: field,
        public num_tickets: u32,
        public ticket_price: u64,
        public event_owner: address,
    ) -> Future {
        let ticket_holder_hash: field = hash_ticket_holder(self.caller, event_id);
        let total_cost: u64 = num_tickets as u64 * ticket_price;
        // Create a record for the purchaser with the credits needed to purchase the tickets.
        let (sender_record, create_record_fut): (credits.aleo/credits, Future) = credits.aleo/transfer_public_to_private(self.caller, total_cost);
        // Transfer funds from the sender's record to the event owner.
        let (change_record, transfer_fut): (credits.aleo/credits, Future) = credits.aleo/transfer_private_to_public(sender_record, event_owner, total_cost);
        
        return finalize_buy_tickets(self.caller, event_id, ticket_holder_hash, num_tickets, create_record_fut, transfer_fut);
    }

    async function finalize_buy_tickets(
        caller: address,
        event_id: field,
        ticket_holder: field,
        num_tickets: u32,
        create_record_fut: Future,
        transfer_fut: Future,
    ) {
        let event: Event = events.get(event_id);
        // Ensure there are enough tickets to fulfill the request.
        assert(event.ticket_supply.gte(num_tickets));
        let total_cost: u64 = num_tickets as u64 * event.ticket_price;

        // Subtract the purchased tickets from the ticket supply.
        let updated_event: Event = Event {
            id: event_id,
            ticket_supply: event.ticket_supply - num_tickets,
            ticket_price: event.ticket_price,
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

        create_record_fut.await();
        transfer_fut.await();
    }


    // Transfer tickets to another account.
    async transition trasnfer_tickets(
        private event_id: field,
        private recipient: address,
        private num_tickets: u32,
    ) -> Future {
        let sender_hash: field = hash_ticket_holder(self.caller, event_id);
        let recipient_hash: field = hash_ticket_holder(recipient, event_id);

        return finalize_transfer_tickets(sender_hash, recipient_hash, num_tickets);
    }

    async function finalize_transfer_tickets(
        sender_hash: field,
        recipient_hash: field,
        num_tickets: u32
    ) {
        // Ensure the caller has enough tickets to fulfill the transfer.
        let sender_tickets: u32 = user_tickets.get(sender_hash);
        assert(sender_tickets.gte(num_tickets));
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
        private ticket_holder: address,
        private num_tickets: u32,
    ) -> Future {
        let ticket_holder_hash: field = hash_ticket_holder(ticket_holder, event_id);
        return finalize_redeem_tickets(ticket_holder_hash, num_tickets);
    }

    async function finalize_redeem_tickets(ticket_holder_hash: field, num_tickets: u32) {
        // Ensure the user has at least as many tickets as they are trying to redeem. 
        let held_tickets: u32 = user_tickets.get(ticket_holder_hash);
        assert(held_tickets.gte(num_tickets));
        user_tickets.set(ticket_holder_hash, held_tickets - num_tickets);
    }
}
