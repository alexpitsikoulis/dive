import credits.aleo;
program dive_v0_1_0.aleo;

struct Event:
    id as field;
    ticket_supply as u32;
    ticket_price as u64;
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

function register_event:
    input r0 as field.private;
    input r1 as u32.private;
    input r2 as u64.private;
    cast r0 r1 r2 self.caller into r3 as Event;
    async register_event r3 into r4;
    output r4 as dive_v0_1_0.aleo/register_event.future;

finalize register_event:
    input r0 as Event.public;
    contains events[r0.id] into r1;
    not r1 into r2;
    assert.eq r2 true;
    set r0 into events[r0.id];

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
    add r3.ticket_supply r2 into r4;
    cast r1 r4 r3.ticket_price r3.event_owner into r5 as Event;
    set r5 into events[r1];

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
    cast r1 r3.ticket_supply r2 r3.event_owner into r4 as Event;
    set r4 into events[r1];

closure hash_ticket_holder:
    input r0 as address;
    input r1 as field;
    cast r0 r1 into r2 as TicketHolder.record;
    hash.bhp256 r2 into r3 as field;
    output r3 as field;

function buy_tickets:
    input r0 as field.private;
    input r1 as u32.public;
    input r2 as u64.public;
    input r3 as address.public;
    call hash_ticket_holder self.caller r0 into r4;
    cast r1 into r5 as u64;
    mul r5 r2 into r6;
    call credits.aleo/transfer_public_to_private self.caller r6 into r7 r8;
    call credits.aleo/transfer_private_to_public r7 r3 r6 into r9 r10;
    async buy_tickets self.caller r0 r4 r1 r8 r10 into r11;
    output r11 as dive_v0_1_0.aleo/buy_tickets.future;

finalize buy_tickets:
    input r0 as address.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as u32.public;
    input r4 as credits.aleo/transfer_public_to_private.future;
    input r5 as credits.aleo/transfer_private_to_public.future;
    await r4;
    await r5;
    get events[r1] into r6;
    gte r6.ticket_supply r3 into r7;
    assert.eq r7 true;
    cast r3 into r8 as u64;
    mul r8 r6.ticket_price into r9;
    sub r6.ticket_supply r3 into r10;
    cast r1 r10 r6.ticket_price r6.event_owner into r11 as Event;
    set r11 into events[r1];
    contains user_tickets[r2] into r12;
    branch.eq r12 false to end_then_0_0;
    get user_tickets[r2] into r13;
    add r13 r3 into r14;
    set r14 into user_tickets[r2];
    branch.eq true true to end_otherwise_0_1;
    position end_then_0_0;
    set r3 into user_tickets[r2];
    position end_otherwise_0_1;

function trasnfer_tickets:
    input r0 as field.private;
    input r1 as address.private;
    input r2 as u32.private;
    call hash_ticket_holder self.caller r0 into r3;
    call hash_ticket_holder r1 r0 into r4;
    async trasnfer_tickets r3 r4 r2 into r5;
    output r5 as dive_v0_1_0.aleo/trasnfer_tickets.future;

finalize trasnfer_tickets:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as u32.public;
    get user_tickets[r0] into r3;
    gte r3 r2 into r4;
    assert.eq r4 true;
    sub r3 r2 into r5;
    set r5 into user_tickets[r0];
    contains user_tickets[r1] into r6;
    branch.eq r6 false to end_then_0_2;
    get user_tickets[r1] into r7;
    add r7 r2 into r8;
    set r8 into user_tickets[r1];
    branch.eq true true to end_otherwise_0_3;
    position end_then_0_2;
    set r2 into user_tickets[r1];
    position end_otherwise_0_3;

function redeem_tickets:
    input r0 as field.private;
    input r1 as address.private;
    input r2 as u32.private;
    call hash_ticket_holder r1 r0 into r3;
    async redeem_tickets r3 r2 into r4;
    output r4 as dive_v0_1_0.aleo/redeem_tickets.future;

finalize redeem_tickets:
    input r0 as field.public;
    input r1 as u32.public;
    get user_tickets[r0] into r2;
    gte r2 r1 into r3;
    assert.eq r3 true;
    sub r2 r1 into r4;
    set r4 into user_tickets[r0];
