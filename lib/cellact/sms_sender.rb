require 'httparty'
require 'logging'

module Cellact

  # this class sends smses and parses repsones
  class SmsSender
    attr_reader :logger, :gateway

    # Create new sms sender with given +gateway+
    def initialize(gateway)
      @gateway = gateway
      @logger = Logging.logger[self.class]
    end

    def wsdl_url
      @gateway.cellact_urls[:send_sms]
    end

    def send_sms(message_text, phones, options = {})
      raise ArgumentError.new("Text must be at least 1 character long") if message_text.blank?
      raise ArgumentError.new("No phones were given") if phones.blank?
      raise ArgumentError.new("Either :sender_name or :sender_number attribute required") if options[:sender_name].blank? && options[:sender_number].blank?
      raise ArgumentError.new("Reply to number must be between 4 to 14 digits: #{options[:sender_number]}") if options[:sender_number].present? && !PhoneNumberUtils.valid_sender_number?(options[:sender_number])
      raise ArgumentError.new("Sender name must be between 2 and 11 latin chars") if options[:sender_name].present? && !PhoneNumberUtils.valid_sender_name?(options[:sender_name])

      options[:sender_number] = "+#{options[:sender_number]}" if options[:sender_number].present?

      phones = [phones] unless phones.is_a?(Array)
      # check that phones are in valid cellular format
      for p in phones
        raise ArgumentError.new("Phone number '#{p}' must be cellular phone with 972 country code") unless PhoneNumberUtils.valid_cellular_phone?(p)
      end

      service = ::Savon::Client.new(wsdl_url)
      logger.debug "#send_sms via webservice: #{wsdl_url}."
      response = service.request(:send) do
        #soap.body = build_soap_body_hash(message_text, phones, options)
        #soap.body do |xml|
        #  build_soap_body_xml(xml, message_text, phones, options)
        #end
        soap.xml do |xml|
          build_soap_xml(xml, message_text, phones, options)
        end
      end
      logger.debug "#send_sms sent SOAP header request: #{service.http.headers.inspect}"
      logger.debug "#send_sms sent SOAP body request xml: #{service.soap.to_xml}"

      #<SendResult><result>true</result><sessionId>c05b21a4-5d7f-4c99-af2e-141b61b2856c</sessionId></SendResult>
      #<SendResult><result>false</result><sessionId /><errorDescription>Address not allowed</errorDescription></SendResult>
      soap_xml = response.doc
      logger.debug "#send_sms - got xml response: \n#{soap_xml}"
      soap_xml.remove_namespaces!

      response = parse_response_xml(soap_xml)
      response.sender_name = options[:sender_name]
      response.sender_number = PhoneNumberUtils.without_starting_plus(options[:sender_number]) if options[:sender_number].present?
      logger.debug "#send_sms - parsed response: #{response.inspect}"
      unless response.ok
        raise Cellact::GatewayError.new(111, "Sms send failed, reason: #{response.error_description}", :soap_xml => soap_xml, :parsed_response => response)
      end
      response
    end

    def build_soap_body_hash(message_text, phones, options = {})
      soap_body = {
        'credentials' => {'username' => @gateway.username, 'password' => @gateway.password, 'company' => @gateway.company},
        'sendRequest' => {
          'application' => 'LA',
          'command' => 'sendtextmt',
          'content' => message_text,
          'sender' => options[:sender_name] || options[:sender_number],
          'destinationAddresses' => phones.collect{|p| {'DestinationAddress' => {'address' => "+#{p}"}} }
        }
      }
      soap_body['sendRequest']['deliveryAddresses'] = {'DeliveryReportAddress' => {'type' => 'http', 'address' => options[:delivery_notification_url]}} if options[:delivery_notification_url].present?
      soap_body
    end

    def build_soap_body_xml(xml, message_text, phones, options = {})
      xml.credentials do |xml|
        xml.username(@gateway.username)
        xml.password(@gateway.password)
        xml.company(@gateway.company)
      end
      xml.sendRequest do |xml|
        xml.application('LA')
        xml.command('sendtextmt')
        if options[:delivery_notification_url].present?
          xml.deliveryAddresses do |xml|
            xml.DeliveryReportAddress do |xml|
              xml.type('http')
              xml.address(options[:delivery_notification_url])
            end
          end
        end
        xml.sender(options[:sender_name] || options[:sender_number])
        xml.content(message_text)
        xml.destinationAddresses do |xml|
          phones.each do |p|
            xml.DestinationAddress do |xml|
              xml.address("+#{p}")
            end
          end
        end
      end
    end

    def build_soap_xml(xml, message_text, phones, options = {})
      namespaces = {
        #'xmlns:wsdl' => "http://www.cellact.com/webservices/",
        'xmlns:soap'=> "http://schemas.xmlsoap.org/soap/envelope/",
        'xmlns:xsi' =>"http://www.w3.org/2001/XMLSchema-instance",
        'xmlns:xsd' =>"http://www.w3.org/2001/XMLSchema"
      }

      xml.soap(:Envelope, namespaces) do |xml|
        xml.soap(:Body) do |xml|
          xml.Send(:xmlns => "http://www.cellact.com/webservices/") do |xml|
            xml.credentials do |xml|
              xml.username(@gateway.username)
              xml.password(@gateway.password)
              xml.company(@gateway.company)
            end
            xml.sendRequest do |xml|
              xml.application('LA')
              xml.command('sendtextmt')
              if options[:delivery_notification_url].present?
                xml.deliveryAddresses do |xml|
                  xml.DeliveryReportAddress do |xml|
                    xml.type('http')
                    xml.address(options[:delivery_notification_url])
                  end
                end
              end
              xml.sender(options[:sender_name] || options[:sender_number])
              xml.content(message_text)
              xml.destinationAddresses do |xml|
                phones.each do |p|
                  xml.DestinationAddress do |xml|
                    xml.address("+#{p}")
                  end
                end
              end
            end
          end
        end
      end
    end

    def parse_response_xml(soap_xml)
      begin
        doc = soap_xml.at_css('SendResult')
        result = {:ok => doc.at_css('result').text == 'true'}
        if result[:ok]
          result[:message_id] = doc.at_css('sessionId').text
        else
          result[:error_description] = doc.at_css('errorDescription').text
        end
        OpenStruct.new(result)
      rescue Exception => e
        raise Cellact::GatewayError.new(250, e.message)
      end
    end

  end

end