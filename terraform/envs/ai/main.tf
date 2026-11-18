
module "knowledge_base" {
  source = "../../modules/knowledge-base"

  name                 = "cloudmart-dev"
  docs_dir             = abspath("${path.root}/../../../knowledge")
  embedding_dimensions = 384

  document_metadata = {
    "returns-and-refunds.md" = {
      category = "policy"
      topic    = "returns"
    }

    "shipping-and-delivery.md" = {
      category = "policy"
      topic    = "shipping"
    }

    "payment-and-pricing.md" = {
      category = "policy"
      topic    = "payment"
    }

    "warranty-and-repairs.md" = {
      category = "policy"
      topic    = "warranty"
    }

    "order-changes-and-cancellations.md" = {
      category = "policy"
      topic    = "orders"
    }

    "faq-account-and-orders.md" = {
      category = "faq"
      topic    = "account"
    }

    "guide-hiking-boots.md" = {
      category = "product-guide"
      product  = "Trail Hiking Boots"
    }

    "guide-rain-jackets.md" = {
      category = "product-guide"
      product  = "Lightweight Rain Jacket"
    }

    "guide-socks-and-layering.md" = {
      category = "product-guide"
      product  = "Merino Wool Socks"
    }

    "guide-bottles-and-headlamps.md" = {
      category = "product-guide"
      product  = "Insulated Water Bottle and LED Headlamp"
    }

    "buying-guide-first-day-hike.md" = {
      category = "buying-guide"
      topic    = "hiking"
    }

    "store-info-and-contact.md" = {
      category = "company"
      topic    = "support"
    }
  }
}
