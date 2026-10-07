namespace order.demo;

/**
 * Sales orders that flow through the n8n approval loop.
 * Status transitions: PENDING -> APPROVED | REJECTED
 */
entity Orders {
  key ID           : UUID;
      customer     : String(100);
      product      : String(100);
      qty          : Integer;
      amount       : Decimal(15, 2);
      currency     : String(3) default 'TRY';

      @assert.range
      status       : String(10) enum {
        PENDING;
        APPROVED;
        REJECTED;
      } default 'PENDING';

      approvedBy   : String(100);
      approvedAt   : Timestamp;
      note         : String(500);
}

/** Master data: customers the AI agent can look up by name. */
entity Customers {
  key ID   : String(10);
      name : String(100);
      city : String(60);
}

/** Master data: price list used to derive Orders.amount. */
entity Products {
  key ID        : String(10);
      name      : String(100);
      unitPrice : Decimal(15, 2);
}
