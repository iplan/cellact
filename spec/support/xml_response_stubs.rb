class XmlResponseStubs

  class << self

    def wrap_in_soap_envelope_response(response_root_node)
      doc = ::Nokogiri::XML(FileMacros.load_xml_file('EnvelopeResponse.soap.xml'))
      doc.at_css('soap|Body').add_child response_root_node
      doc.to_xml
    end

    def send_sms_response(response_options = {})
      doc = ::Nokogiri::XML(FileMacros.load_xml_file('SendSmsResponse.soap.xml'))
      doc.at_css('result').content = response_options[:result].to_s
      if response_options[:result] == 'true' || response_options[:result] == true
        doc.at_css('sessionId').content = response_options[:sessionId]
      else
        doc.at_css('sessionId').content = ''
        doc.at_css('errorDescription').content = response_options[:errorDescription]
      end
      doc.root
    end

    def stub_request_with_sms_send_response(example, wsdl_url, options = {})
      options = {:http_code => 200}.update(options)
      http_code = options.delete(:http_code)
      example.stub_request(:get, wsdl_url).to_return(:status => http_code, :body => FileMacros.load_xml_file('SendSms.asmx.wsdl.xml'))
      example.stub_request(:post, wsdl_url.gsub('?WSDL', '')).to_return(:status => http_code, :body => wrap_in_soap_envelope_response(XmlResponseStubs.send_sms_response(options)))
    end

    def delivery_notification_http_xml_string(values_hash = {})
      doc = ::Nokogiri::XML(FileMacros.load_xml_file('DeliveryNotificationPush.xml'))
      root = doc.at_css('PALO')
      values_hash.each do |key, value|
        root.at_css(key.to_s).content = value
      end
      root.to_s
    end

    def sms_reply_http_xml_string(values_hash = {})
      doc = ::Nokogiri::XML(FileMacros.load_xml_file('SmsReplyPush.xml'))
      root = doc.at_css('IncomingData')
      values_hash.each do |key, value|
        root.at_css(key.to_s).content = value
      end
      root.to_s
    end
  end

end