const cds = require('@sap/cds')

const LOG = cds.log('order-service')

// Fire-and-forget webhook settings. The demo must survive n8n being down.
const WEBHOOK_TIMEOUT_MS = Number(process.env.N8N_WEBHOOK_TIMEOUT_MS || 3000)

/**
 * Notify n8n that a new order was created.
 * Deliberately never throws and never blocks the OData response:
 * if n8n is offline the order is still persisted, we only log a warning.
 */
async function notifyN8n(order) {
  const url = process.env.N8N_WEBHOOK_URL
  if (!url) {
    LOG.warn('N8N_WEBHOOK_URL is not set - skipping approval webhook for order', order.ID)
    return
  }

  const payload = {
    ID: order.ID,
    customer: order.customer,
    product: order.product,
    qty: order.qty,
    amount: order.amount,
    currency: order.currency
  }

  const headers = { 'Content-Type': 'application/json' }
  if (process.env.N8N_WEBHOOK_KEY) headers['X-API-Key'] = process.env.N8N_WEBHOOK_KEY

  try {
    const res = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(WEBHOOK_TIMEOUT_MS)
    })
    if (res.ok) {
      LOG.info('n8n webhook triggered for order', order.ID, `(${order.amount} ${order.currency})`)
    } else {
      LOG.warn(`n8n webhook returned HTTP ${res.status} for order ${order.ID} - order was still created`)
    }
  } catch (e) {
    // n8n down, wrong port, no network - none of that may break order creation.
    LOG.warn(`n8n webhook failed for order ${order.ID}: ${e.message} - order was still created`)
  }
}

module.exports = class OrderService extends cds.ApplicationService {
  init() {
    const { Orders, Products } = this.entities

    /** Shared implementation for approve / reject. Idempotent by design. */
    const decide = async (req, { targetStatus, approvedBy, note }) => {
      const ID = req.data.ID
      if (!ID) return req.reject(400, 'ID is required')

      const order = await SELECT.one.from(Orders).where({ ID })
      if (!order) return req.reject(404, `Order ${ID} not found`)

      // Idempotency: a repeated Telegram click or a webhook retry must not
      // flip an already-decided order, and must not error out either.
      if (order.status === targetStatus) {
        LOG.info(`Order ${ID} is already ${targetStatus} - returning existing record (idempotent)`)
        return order
      }
      if (order.status !== 'PENDING') {
        return req.reject(409, `Order ${ID} is already ${order.status} and cannot be set to ${targetStatus}`)
      }

      const changes = {
        status: targetStatus,
        approvedBy,
        approvedAt: new Date().toISOString()
      }
      if (note) changes.note = note

      await UPDATE(Orders).set(changes).where({ ID })
      LOG.info(`Order ${ID} -> ${targetStatus} by ${approvedBy}`)

      return await SELECT.one.from(Orders).where({ ID })
    }

    /* ---------------------------------------------------------------
     * before CREATE - fill in what the caller (or the AI agent) omitted
     * --------------------------------------------------------------- */
    this.before('CREATE', Orders, async (req) => {
      const d = req.data

      if (!d.currency) d.currency = 'TRY'
      if (!d.status) d.status = 'PENDING'

      // Derive amount from the price list when the caller did not send one.
      if (d.amount === undefined || d.amount === null || d.amount === '') {
        const qty = Number(d.qty || 0)
        if (!qty) return req.reject(400, 'qty is required when amount is not supplied')

        const product = await SELECT.one.from(Products).where({ name: d.product })
        if (!product) {
          return req.reject(400, `Unknown product '${d.product}' - amount cannot be calculated`)
        }

        d.amount = Number((qty * Number(product.unitPrice)).toFixed(2))
        LOG.info(`Calculated amount for ${d.product}: ${qty} x ${product.unitPrice} = ${d.amount}`)
      }
    })

    /* ---------------------------------------------------------------
     * after CREATE - kick off the n8n approval workflow (Act 1).
     * Fired on 'succeeded' so the row is committed before n8n can call
     * approve/reject back - otherwise the callback races the INSERT.
     * --------------------------------------------------------------- */
    this.after('CREATE', Orders, (result, req) => {
      // CDS >= 9 hands `after CREATE` only the keys (wrapped in an array);
      // the complete payload lives in req.data. Merge both so this handler
      // keeps working on older and newer @sap/cds alike.
      const head = Array.isArray(result) ? result[0] : result
      const created = { ...head, ...req.data }

      req.on('succeeded', () => notifyN8n(created))
    })

    /* ---------------------------------------------------------------
     * Unbound actions called back by n8n
     * --------------------------------------------------------------- */
    this.on('approve', (req) => decide(req, {
      targetStatus: 'APPROVED',
      approvedBy: req.data.approvedBy || 'n8n'
    }))

    // reject(ID, reason) per spec - the reason text carries who rejected.
    this.on('reject', (req) => decide(req, {
      targetStatus: 'REJECTED',
      approvedBy: 'n8n',
      note: req.data.reason
    }))

    return super.init()
  }
}
