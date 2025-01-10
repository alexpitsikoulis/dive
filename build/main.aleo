import credits.aleo;
program dive_v0_1_0.aleo;

struct Event:
    id as field;
    ticket_supply as u32;
    ticket_price as u64;
    deadline as u64;
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
    input r3 as u64.private;
    cast r0 r1 r2 r3 self.caller into r4 as Event;
    async register_event r4 into r5;
    output r5 as dive_v0_1_0.aleo/register_event.future;

finalize register_event:
    input r0 as Event.public;
    contains events[r0.id] into r1;
    not r1 into r2;
    assert.eq r2 true;
    set r0 into events[r0.id];

function add_tickets:
    input r0 as field.private;
    input r1 as u32.private;
    input r2 as u64.private;
    async add_tickets self.caller r0 r1 r2 into r3;
    output r3 as dive_v0_1_0.aleo/add_tickets.future;

finalize add_tickets:
    input r0 as address.public;
    input r1 as field.public;
    input r2 as u32.public;
    input r3 as u64.public;
    get events[r1] into r4;
    assert.eq r0 r4.event_owner;
    lt r3 r4.deadline into r5;
    assert.eq r5 true;
    add r4.ticket_supply r2 into r6;
    cast r1 r6 r4.ticket_price r4.deadline r4.event_owner into r7 as Event;
    set r7 into events[r1];

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
    cast r1 r3.ticket_supply r2 r3.deadline r3.event_owner into r4 as Event;
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
    input r4 as u64.public;
    call hash_ticket_holder self.caller r0 into r5;
    cast r1 into r6 as u64;
    mul r6 r2 into r7;
    call credits.aleo/transfer_public_to_private self.caller r7 into r8 r9;
    call credits.aleo/transfer_private_to_public r8 r3 r7 into r10 r11;
    async buy_tickets self.caller r0 r5 r1 r4 r9 r11 into r12;
    output r12 as dive_v0_1_0.aleo/buy_tickets.future;

finalize buy_tickets:
    input r0 as address.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as u32.public;
    input r4 as u64.public;
    input r5 as credits.aleo/transfer_public_to_private.future;
    input r6 as credits.aleo/transfer_private_to_public.future;
    get events[r1] into r7;
    gte r7.ticket_supply r3 into r8;
    assert.eq r8 true;
    lt r4 r7.deadline into r9;
    assert.eq r9 true;
    cast r3 into r10 as u64;
    mul r10 r7.ticket_price into r11;
    sub r7.ticket_supply r3 into r12;
    cast r1 r12 r7.ticket_price r7.deadline r7.event_owner into r13 as Event;
    set r13 into events[r1];
    contains user_tickets[r2] into r14;
    branch.eq r14 false to end_then_0_0;
    get user_tickets[r2] into r15;
    add r15 r3 into r16;
    set r16 into user_tickets[r2];
    branch.eq true true to end_otherwise_0_1;
    position end_then_0_0;
    set r3 into user_tickets[r2];
    position end_otherwise_0_1;
    await r5;
    await r6;

function trasnfer_tickets:
    input r0 as field.private;
    input r1 as address.private;
    input r2 as u32.private;
    input r3 as u64.public;
    call hash_ticket_holder self.caller r0 into r4;
    call hash_ticket_holder r1 r0 into r5;
    async trasnfer_tickets r0 r4 r5 r2 r3 into r6;
    output r6 as dive_v0_1_0.aleo/trasnfer_tickets.future;

finalize trasnfer_tickets:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as u32.public;
    input r4 as u64.public;
    get user_tickets[r1] into r5;
    gte r5 r3 into r6;
    assert.eq r6 true;
    get events[r0] into r7;
    lt r4 r7.deadline into r8;
    assert.eq r8 true;
    sub r5 r3 into r9;
    set r9 into user_tickets[r1];
    contains user_tickets[r2] into r10;
    branch.eq r10 false to end_then_0_2;
    get user_tickets[r2] into r11;
    add r11 r3 into r12;
    set r12 into user_tickets[r2];
    branch.eq true true to end_otherwise_0_3;
    position end_then_0_2;
    set r3 into user_tickets[r2];
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
