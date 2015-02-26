require 'nokogiri'

module XMLgenerator
  SCHEMA_VERSION = "3.2"
  EUR            = "EUR"

  class Generator
    attr_accessor :header
    attr_accessor :detail_list
    attr_accessor :tax_list
    attr_accessor :total
    attr_accessor :installment_list

    def initialize
      clear
      @xml = Nokogiri::XML(
        '<fe:Facturae xmlns:ds="http://www.w3.org/2000/09/xmldsig#" '+
      'xmlns:fe="http://www.facturae.es/Facturae/2009/v3.2/Facturae"</fe:Facturae>')
      @root = @xml.root
    end

    def clear
      @header = nil
      @detail_list = []
      @tax_list = []
      @total = nil
      @installment_list = []

    end

    def add_row(row)
      case row.row_kind
      when 1
        @header = row
      when 2
        @detail_list << row
      when 3
        @tax_list << row
      when 4
        @total = row
      when 5
        @installment_list << row
      end
    end

    def generate_xml
      @issuer = Issuer.find_by(tax_id: @header.issuer_tax_id)
      @root.add_child(file_header)
      @root.add_child(parties)
      @root.add_child(invoices)

      @xml.to_s.gsub(/ xmlns=""/) { |match| } # only way I found to remove name space footprint
    end

    private

################################
    def file_header
################################
      result = new_node("FileHeader")
      result.default_namespace = "" # I've not found better way to avoid name space in every child tag
      result.add_child(new_node(
      "SchemaVersion",SCHEMA_VERSION))
      result.add_child(new_node(
      "Modality","I"))
      result.add_child(new_node(
      "InvoiceIssuerType","EM"))
      result.add_child(batch)
      result
    end

    def batch
      result = new_node("Batch")
      result.default_namespace = "" # I've not found better way to avoid name space in every child tag
      result.add_child(new_node(
      "BatchIdentifier",@header.customer_tax_id+@header.invoice_number+@header.invoice_serie))
      result.add_child(new_node(
      "InvoicesCount","1"))
      result.add_child(new_node(
      "TotalInvoicesAmount")).add_child(
        new_node("TotalAmount",
                 Formatter.format_2D(@total.total_invoice.to_f)))
      result.add_child(new_node(
      "TotalOutstandingAmount")).add_child(
        new_node("TotalAmount",
                 Formatter.format_2D(@total.total_invoice.to_f)))
      result.add_child(new_node(
      "TotalExecutableAmount")).add_child(
        new_node("TotalAmount",
                 Formatter.format_2D(@total.total_invoice.to_f)))
      result.add_child(new_node(
      "TotalExecutableAmount")).add_child(
      new_node("InvoiceCurrencyCode",EUR))
      result
    end

################################
    def parties
################################
      result = new_node("Parties")
      result.default_namespace = "" # I've not found better way to avoid name space in every child tag
      result.add_child(seller_party)
      result.add_child(buyer_party)
      result
    end

    def seller_party
      result = new_node("SellerParty")
      tax_identification = new_node("TaxIdentification")
      tax_identification.add_child(new_node("PersonTypeCode",@issuer.person_type_code))
      tax_identification.add_child(new_node("ResidenceTypeCode",@issuer.residence_type_code))
      tax_identification.add_child(new_node("TaxIdentificationNumber",@issuer.tax_id))
      result.add_child(tax_identification)

      legal_entity = new_node("LegalEntity")
      legal_entity.add_child(new_node("CorporateName",@issuer.company_name))
      address_in_spain = new_node("AddressInSpain")
      address_in_spain.add_child(new_node("Address",@issuer.address))
      # TODO: add post_code to issuer
      address_in_spain.add_child(new_node("PostCode","07703")) # @issuer.post_code))
      address_in_spain.add_child(new_node("Town",@issuer.town))
      address_in_spain.add_child(new_node("Province",@issuer.province))
      address_in_spain.add_child(new_node("CountryCode",@issuer.country_code))
      legal_entity.add_child(address_in_spain)
      result.add_child(legal_entity)
      result
    end

    def buyer_party
      result = new_node("BuyerParty")
      tax_identification = new_node("TaxIdentification")
      tax_identification.add_child(new_node("PersonTypeCode","J"))
      tax_identification.add_child(new_node("ResidenceTypeCode","R"))
      tax_identification.add_child(new_node("TaxIdentificationNumber",@header.customer_tax_id))
      result.add_child(tax_identification)

      administrative_centres = new_node("AdministrativeCentres")
      administrative_centres.add_child(administrative_centre(2))
      administrative_centres.add_child(administrative_centre(3))
      administrative_centres.add_child(administrative_centre(1))
      result.add_child(administrative_centres)

      legal_entity = new_node("LegalEntity")
      legal_entity.add_child(new_node("CorporateName",@header.customer_name))

      address_in_spain = new_node("AddressInSpain")
      address_in_spain.add_child(new_node("Address",@header.customer_address))
      address_in_spain.add_child(new_node("PostCode",@header.customer_postal_code))
      address_in_spain.add_child(new_node("Town",@header.customer_town))
      address_in_spain.add_child(new_node("Province",@header.customer_province))
      address_in_spain.add_child(new_node("CountryCode","ESP"))
      legal_entity.add_child(address_in_spain)
      result.add_child(legal_entity)
      result
    end

    def administrative_centre(role)
      case role
      when 1
        centre_code = @header.customer_accounting_service
      when 2
        centre_code = @header.customer_management_unit
      when 3
        centre_code = @header.customer_processing_unit
      end
      result = new_node("AdministrativeCentre")
      result.add_child(new_node("CentreCode",centre_code))
      result.add_child(new_node("RoleTypeCode",Formatter.format_zeros(role,2)))
      result.add_child(new_node("Name",@header.customer_name))
      address_in_spain = new_node("AddressInSpain")
      address_in_spain.add_child(new_node("Address",@header.customer_address))
      address_in_spain.add_child(new_node("PostCode",@header.customer_postal_code))
      address_in_spain.add_child(new_node("Town",@header.customer_town))
      address_in_spain.add_child(new_node("Province",@header.customer_province))
      address_in_spain.add_child(new_node("CountryCode","ESP"))
      result.add_child(address_in_spain)
      result
    end

################################
    def invoices
################################
      result = new_node("Invoices")
      result.default_namespace = "" # I've not found better way to avoid name space in every child tag
      result.add_child(invoice)

      result
    end

    def invoice
      result = new_node("Invoice")
      invoice_header = new_node("InvoiceHeader")
      invoice_header.add_child(new_node("InvoiceNumber",@header.invoice_number))
      invoice_header.add_child(new_node("InvoiceSeriesCode",@header.invoice_serie))
      invoice_header.add_child(new_node("InvoiceDocumentType","FC"))
      invoice_header.add_child(new_node("InvoiceClass","OO"))
      result.add_child(invoice_header)

      invoice_issue_data = new_node("InvoiceIssueData")
      invoice_issue_data.add_child(new_node("IssueDate",@header.invoice_date))
      place_of_issue = new_node("PlaceOfIssue")
      # TODO: add post_code to issuer
      place_of_issue.add_child(new_node("PostCode","07703")) # @issuer.post_code))
      place_of_issue.add_child(new_node("PlaceOfIssueDescription",@issuer.town))
      invoice_issue_data.add_child(place_of_issue)

      invoice_issue_data.add_child(new_node("InvoiceCurrencyCode",EUR))
      invoice_issue_data.add_child(new_node("TaxCurrencyCode",EUR))
      invoice_issue_data.add_child(new_node("LanguageName","es"))

      result.add_child(taxes_outputs)

      result.add_child(invoice_totals)

      result
    end

    def taxes_outputs
      result = new_node("TaxesOutputs")
      @tax_list.each do |tax|
        result.add_child(tax_node(tax))
      end

      result
    end

    def tax_node(tax)
      result = new_node("Tax")
      result.add_child(new_node("TaxTypeCode","01"))
      result.add_child(new_node("TaxRate",Formatter.format_2D(tax.tax_rate)))
      result.add_child(new_node(
        "TaxableBase")).add_child(new_node(
          "TotalAmount",Formatter.format_2D(tax.tax_base)))
      result.add_child(new_node(
        "TaxAmount")).add_child(new_node(
          "TotalAmount",Formatter.format_2D(tax.tax_amount)))

      result
    end

    def invoice_totals
      result = new_node("InvoiceTotals")
      result.add_child(new_node(
        "TotalGrossAmount",Formatter.format_2D(@total.total_gross_amount)))

      # TODO: GeneralDiscounts -> irene2

      # result.add_child(new_node(
      #   "TotalGeneralDiscounts",Formatter.format_2D(@total.total_gross_amount)))

      result
    end

    def new_node(tag, value = "")
      result =  Nokogiri::XML::Node.new(tag, @xml)
      result.add_child(value)
      result
    end

  end

  class Formatter
    def self.format_2D(value)
      format("%.2f", value)
    end
    def self.format_zeros(value,len)
      format = "%0#{len}d"
      result = format(format, value)
      if result.length > len
        result.slice!(1..len)
      end
      result
    end
  end
end

__END__
      # xml = []
      # xml << @header
      # @detail_list.each do |detail| 
      #   xml << detail
      # end
      # @tax_list.each do |tax| 
      #   xml << tax
      # end
      # xml << @total
      # @installment_list.each do |installment| 
      #   xml << installment
      # end
      # xml
