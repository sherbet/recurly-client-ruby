module Recurly
  # Invoices are created through account objects.
  #
  # @example
  #   account = Account.find account_code
  #   account.invoice!
  class Invoice < Resource
    # @macro [attach] scope
    #   @scope class
    #   @return [Pager<Invoice>] A pager that yields +$1+ invoices.
    scope :open,      :state => :open
    scope :collected, :state => :collected
    scope :failed,    :state => :failed
    scope :past_due,  :state => :past_due

    # @return [Account]
    belongs_to :account
    # @return [Subscription]
    belongs_to :subscription

    # @return [Redemption]
    has_many :redemptions

    def redemption
      redemptions.first
    end

    define_attribute_methods %w(
      uuid
      state
      invoice_number
      po_number
      vat_number
      subtotal_in_cents
      tax_in_cents
      total_in_cents
      currency
      created_at
      closed_at
      line_items
      transactions
      amount_remaining_in_cents
    )
    alias to_param invoice_number

    # Marks an invoice as paid successfully.
    #
    # @return [true, false] +true+ when successful, +false+ when unable to
    #   (e.g., the invoice is no longer open).
    def mark_successful
      return false unless link? :mark_successful
      reload follow_link :mark_successful
      true
    end

    # Marks an invoice as failing collection.
    #
    # @return [true, false] +true+ when successful, +false+ when unable to
    #   (e.g., the invoice is no longer open).
    def mark_failed
      return false unless link? :mark_failed
      reload follow_link :mark_failed
      true
    end

    def pdf
      self.class.find to_param, :format => 'pdf'
    end

    # Refunds specific line items on the invoice.
    #
    # @return [Invoice, false] A new refund invoice, false if the invoice isn't
    # refundable.
    # @raise [Error] If the refund fails.
    # @param line_items [Array, nil] An array of line items to refund.
    def refund line_items = nil, refund_apply_order = 'credit'
      return false unless link? :refund
      refund = self.class.from_response(
        follow_link :refund, :body => refund_line_items_to_xml(line_items, refund_apply_order)
      )
      refund
    end

    # Refunds the invoice for a specific amount.
    #
    # @return [Invoice, false] A new refund invoice, false if the invoice isn't
    # refundable.
    # @raise [Error] If the refund fails.
    # @param amount_in_cents [Integer, nil] The amount (in cents) to refund.
    def refund_amount amount_in_cents = nil, refund_apply_order = 'credit'
      return false unless link? :refund
      refund = self.class.from_response(
        follow_link :refund, :body => refund_amount_to_xml(amount_in_cents, refund_apply_order)
      )
      refund
    end

    private

    def initialize attributes = {}
      super({ :currency => Recurly.default_currency }.merge attributes)
    end

    def refund_amount_to_xml amount_in_cents = nil, refund_apply_order
      builder = XML.new("<invoice/>")
      builder.add_element 'refund_apply_order', refund_apply_order
      builder.add_element 'amount_in_cents', amount_in_cents
      builder.to_s
    end

    def refund_line_items_to_xml line_items = [], refund_apply_order
      builder = XML.new("<invoice/>")
      builder.add_element 'refund_apply_order', refund_apply_order

      node = builder.add_element 'line_items'
      line_items.each do |line_item|
        adj_node = node.add_element 'adjustment'
        adj_node.add_element 'uuid', line_item[:adjustment].uuid
        adj_node.add_element 'quantity', line_item[:quantity]
        adj_node.add_element 'prorate', line_item[:prorate]
      end
      builder.to_s
    end

    # Invoices are only writeable through {Account} instances.
    embedded! true
    undef save
    undef destroy
  end
end
