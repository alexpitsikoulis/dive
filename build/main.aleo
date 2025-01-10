import credits.aleo;
program dive_v0_1_0.aleo;

struct Event:
    id as field;
    initial_supply as u32;
    ticket_supply as u32;
    redeemed_tickets as u32;
    ticket_price as u64;
    is_ended as boolean;
    is_refunded as boolean;
    event_owner as address;

record TicketHolder:
    owner as address.private;
    event_id as field.private;

mapping events:
    key as field.public;
    value as Event.public;

mapping user_tickets:
    key as field.public;
    value as u32.public;

mapping payouts:
    key as address.public;
    value as u64.public;

function register_event:
    input r0 as field.private;
    input r1 as u32.private;
    input r2 as u64.private;
    cast r0 r1 r1 0u32 r2 false false self.caller into r3 as Event;
    async register_event r3 into r4;
    output r4 as dive_v0_1_0.aleo/register_event.future;

finalize register_event:
    input r0 as Event.public;
    contains events[r0.id] into r1;
    not r1 into r2;
    assert.eq r2 true;
    set r0 into events[r0.id];
    contains payouts[r0.event_owner] into r3;
    not r3 into r4;
    branch.eq r4 false to end_then_0_0;
    set 0u64 into payouts[r0.event_owner];
    branch.eq true true to end_otherwise_0_1;
    position end_then_0_0;
    position end_otherwise_0_1;

function add_tickets:
    input r0 as field.private;
    input r1 as u32.private;
    async add_tickets self.caller r0 r1 into r2;
    output r2 as dive_v0_1_0.aleo/add_tickets.future;

finalize add_tickets:
    input r0 as address.public;
    input r1 as field.public;
    input r2 as u32.public;
    get events[r1] into r3;
    assert.eq r0 r3.event_owner;
    not r3.is_ended into r4;
    not r3.is_refunded into r5;
    and r4 r5 into r6;
    assert.eq r6 true;
    add r3.initial_supply r2 into r7;
    add r3.ticket_supply r2 into r8;
    cast r1 r7 r8 r3.redeemed_tickets r3.ticket_price false false r3.event_owner into r9 as Event;
    set r9 into events[r1];

function update_price:
    input r0 as field.private;
    input r1 as u64.private;
    async update_price self.caller r0 r1 into r2;
    output r2 as dive_v0_1_0.aleo/update_price.future;

finalize update_price:
    input r0 as address.public;
    input r1 as field.public;
    input r2 as u64.public;
    get events[r1] into r3;
    assert.eq r0 r3.event_owner;
    not r3.is_ended into r4;
    not r3.is_refunded into r5;
    and r4 r5 into r6;
    assert.eq r6 true;
    cast r1 r3.initial_supply r3.ticket_supply r3.redeemed_tickets r2 r3.is_ended r3.is_refunded r3.event_owner into r7 as Event;
    set r7 into events[r1];

function end_event:
    input r0 as field.private;
    async end_event r0 into r1;
    output r1 as dive_v0_1_0.aleo/end_event.future;

finalize end_event:
    input r0 as field.public;
    get events[r0] into r1;
    sub r1.initial_supply r1.ticket_supply into r2;
    not r1.is_ended into r3;
    not r1.is_refunded into r4;
    and r3 r4 into r5;
    assert.eq r5 true;
    mul r1.redeemed_tickets 2u32 into r6;
    gte r6 r2 into r7;
    branch.eq r7 false to end_then_0_2;
    cast r0 r1.initial_supply r1.ticket_supply r1.redeemed_tickets r1.ticket_price true false r1.event_owner into r8 as Event;
    set r8 into events[r0];
    branch.eq true true to end_otherwise_0_3;
    position end_then_0_2;
    cast r0 r1.initial_supply r1.ticket_supply r1.redeemed_tickets r1.ticket_price true true r1.event_owner into r9 as Event;
    set r9 into events[r0];
    position end_otherwise_0_3;

function refund_event:
    input r0 as field.private;
    async refund_event r0 into r1;
    output r1 as dive_v0_1_0.aleo/refund_event.future;

finalize refund_event:
    input r0 as field.public;
    get events[r0] into r1;
    not r1.is_ended into r2;
    not r1.is_refunded into r3;
    and r2 r3 into r4;
    assert.eq r4 true;
    cast r0 r1.initial_supply r1.ticket_supply r1.redeemed_tickets r1.ticket_price true true r1.event_owner into r5 as Event;
    set r5 into events[r0];

closure hash_ticket_holder:
    input r0 as address;
    input r1 as field;
    cast r0 r1 into r2 as TicketHolder.record;
    hash.bhp256 r2 into r3 as field;
    output r3 as field;

function buy_tickets:
    input r0 as field.private;
    input r1 as credits.aleo/credits.record;
    input r2 as u32.public;
    input r3 as u64.public;
    input r4 as address.public;
    assert.eq self.caller r1.owner;
    call hash_ticket_holder self.caller r0 into r5;
    cast r2 into r6 as u64;
    mul r6 r3 into r7;
    call credits.aleo/transfer_private_to_public r1 dive_v0_1_0.aleo r7 into r8 r9;
    async buy_tickets r0 r5 r2 r9 into r10;
    output r8 as credits.aleo/credits.record;
    output r10 as dive_v0_1_0.aleo/buy_tickets.future;

finalize buy_tickets:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as u32.public;
    input r3 as credits.aleo/transfer_private_to_public.future;
    get events[r0] into r4;
    gte r4.ticket_supply r2 into r5;
    assert.eq r5 true;
    not r4.is_ended into r6;
    not r4.is_refunded into r7;
    and r6 r7 into r8;
    assert.eq r8 true;
    cast r2 into r9 as u64;
    mul r9 r4.ticket_price into r10;
    sub r4.ticket_supply r2 into r11;
    cast r0 r4.initial_supply r11 r4.redeemed_tickets r4.ticket_price r4.is_ended r4.is_refunded r4.event_owner into r12 as Event;
    set r12 into events[r0];
    contains user_tickets[r1] into r13;
    branch.eq r13 false to end_then_0_4;
    get user_tickets[r1] into r14;
    add r14 r2 into r15;
    set r15 into user_tickets[r1];
    branch.eq true true to end_otherwise_0_5;
    position end_then_0_4;
    set r2 into user_tickets[r1];
    position end_otherwise_0_5;
    get payouts[r4.event_owner] into r16;
    add r16 r10 into r17;
    set r17 into payouts[r4.event_owner];
    await r3;

function transfer_tickets:
    input r0 as field.private;
    input r1 as address.private;
    input r2 as u32.private;
    input r3 as u64.public;
    call hash_ticket_holder self.caller r0 into r4;
    call hash_ticket_holder r1 r0 into r5;
    async transfer_tickets r0 r4 r5 r2 r3 into r6;
    output r6 as dive_v0_1_0.aleo/transfer_tickets.future;

finalize transfer_tickets:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as u32.public;
    input r4 as u64.public;
    get user_tickets[r1] into r5;
    gte r5 r3 into r6;
    assert.eq r6 true;
    get events[r0] into r7;
    not r7.is_ended into r8;
    not r7.is_refunded into r9;
    and r8 r9 into r10;
    assert.eq r10 true;
    sub r5 r3 into r11;
    set r11 into user_tickets[r1];
    contains user_tickets[r2] into r12;
    branch.eq r12 false to end_then_0_6;
    get user_tickets[r2] into r13;
    add r13 r3 into r14;
    set r14 into user_tickets[r2];
    branch.eq true true to end_otherwise_0_7;
    position end_then_0_6;
    set r3 into user_tickets[r2];
    position end_otherwise_0_7;

function redeem_tickets:
    input r0 as field.private;
    input r1 as u32.private;
    call hash_ticket_holder self.caller r0 into r2;
    async redeem_tickets r0 r2 r1 into r3;
    output r3 as dive_v0_1_0.aleo/redeem_tickets.future;

finalize redeem_tickets:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as u32.public;
    get user_tickets[r1] into r3;
    gte r3 r2 into r4;
    assert.eq r4 true;
    sub r3 r2 into r5;
    set r5 into user_tickets[r1];
    get events[r0] into r6;
    not r6.is_ended into r7;
    not r6.is_refunded into r8;
    and r7 r8 into r9;
    assert.eq r9 true;
    add r6.redeemed_tickets r2 into r10;
    cast r0 r6.initial_supply r6.ticket_supply r10 r6.ticket_price r6.is_ended r6.is_refunded r6.event_owner into r11 as Event;
    set r11 into events[r0];

function claim_refund:
    input r0 as field.private;
    input r1 as credits.aleo/credits.record;
    call hash_ticket_holder r1.owner r0 into r2;
    async claim_refund r0 r2 into r3;
    output r3 as dive_v0_1_0.aleo/claim_refund.future;

finalize claim_refund:
    input r0 as field.public;
    input r1 as field.public;
    get user_tickets[r1] into r2;
    gte r2 1u32 into r3;
    assert.eq r3 true;
    get events[r0] into r4;
    assert.eq r4.is_refunded true;
    set 0u32 into user_tickets[r1];
