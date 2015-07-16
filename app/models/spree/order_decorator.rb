Spree::Order.class_eval do

  # Updates +invoice_number+ without calling ActiveRecord callbacks
  #
  # Only updates if number is not already present and if
  # +Spree::PrintInvoice::Config.next_number+ is set and greater than zero.
  #
  # Also sets +invoice_date+ to current date.
  #
  def update_invoice_number!
    return unless Spree::PrintInvoice::Config.use_sequential_number?
    return if invoice_number.present?

    update_columns(
      invoice_number: Spree::PrintInvoice::Config.increase_invoice_number,
      invoice_date: Date.today
    )
  end

  # Returns the given template as pdf binary suitable for Rails send_data
  #
  # If the file is already present it returns this
  # else it generates a new file, stores and returns this.
  #
  # You can disable the pdf file generation with setting
  #
  #   Spree::PrintInvoice::Config.store_pdf to false
  #
  def pdf_file(template)
    if Spree::PrintInvoice::Config.store_pdf
      send_or_create_pdf(template)
    else
      render_pdf(template)
    end
  end

  # = The PDF filename
  #
  # Tries to take invoice_number attribute.
  # If this is not present it takes the order number.
  #
  def pdf_filename
    invoice_number.present? ? invoice_number : number
  end

  # = PDF file path for template name
  #
  def pdf_file_path(template)
    Rails.root.join(pdf_storage_path(template), "#{pdf_filename}.pdf")
  end

  # = PDF storage folder path for given template name
  #
  # Configure the storage path with +Spree::PrintInvoice::Config.storage_path+
  #
  # Each template type gets it own pluralized folder inside
  # of +Spree::PrintInvoice::Config.storage_path+
  #
  # == Example:
  #
  #   pdf_storage_path('invoice') => "tmp/pdf_prints/invoices"
  #
  # Creates the folder if it's not present yet.
  #
  def pdf_storage_path(template)
    storage_path = Rails.root.join(Spree::PrintInvoice::Config.storage_path, template.pluralize)
    FileUtils.mkdir_p(storage_path)
    storage_path
  end

  # Renders the prawn template for give template name in context of ActionView.
  #
  # Prawn templates need to be placed in +app/views/spree/admin/orders/+ folder.
  #
  # Assigns +@order+ and +@logo_image_file_path+ instance variable
  #
  def render_pdf(template)
    ActionView::Base.new(
      ActionController::Base.view_paths,
      { order: self,
        logo_image_file_path: logo_image_file_path
      }).render(template: "spree/admin/orders/#{template}.pdf.prawn")
  end

  private

  # Sends stored pdf for given template from disk.
  #
  # Renders and stores it if it's not yet present.
  #
  def send_or_create_pdf(template)
    file_path = pdf_file_path(template)

    unless File.exist?(file_path)
      # If an error occures while rendering the invoice pdf then no file gets stored and the exception is raised  ...
      invoice_pdf = render_pdf(template)

      File.open(file_path, "wb") { |f| f.puts invoice_pdf }
    end

    IO.binread(file_path)
  end

  def logo_image_file_path

    config_logo_path = Spree::PrintInvoice::Config[:logo_path]

    return nil if config_logo_path.blank?

    # Trying to extract the image from the Rails Assets
    logo_image_file_path = if asset_image = Rails.application.assets.find_asset(config_logo_path)
                        asset_image.pathname
                      else
                        config_logo_path
                      end

    unless File.exist?(logo_image_file_path)
      Rails.logger.warn("============")
      Rails.logger.warn("============")
      Rails.logger.warn("!!! The absolute logo file path '#{logo_image_file_path}' does not exist. The logo image will not be included! Please insert a correct logo image!")
      Rails.logger.warn("============")
      Rails.logger.warn("============")
      return nil
    end


    return logo_image_file_path

  end
end
