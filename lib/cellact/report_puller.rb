module Smsim
  class ReportPuller
    attr_reader :logger

    # create new reports puller for given gateway
    def initialize(gateway)
      @gateway = gateway
      @logger = Logging.logger[self.class]
    end

    def wsdl_url
      @gateway.inforu_urls[:delivery_notifications_and_sms_replies_report_pull]
    end

    # This method will pull sms replies and delivery notifications report from smsim webservice.
    # NOTE!!! Only new delivery notifications and sms replies will be pulled on each subsequent call (after each pull they empty their table)
    #
    # This method returns result object that contains the following attributes:
    # * +status+ - report pull status (should be 1 if everything ok)
    # * +batch_size+ - how many messages pulled (notifications and sms replies combined)
    # * +notifications+ - array of notification delivery objects (see Smsim::DeliveryNotificationsParser#parse_notification_values_hash for object attributes)
    # * +replies+ - array of sms replies objects (see Smsim::SmsRepliesParser.parse_reply_values_hash for object attributes)
    def pull_delivery_notifications_and_sms_replies(batch_size = 100)
      service = Savon::Client.new(wsdl_url)
      soap_body = {'userName' => @gateway.username, 'password' => @gateway.password, 'batchSize' => batch_size}
      logger.debug "Request delivery notifications and incoming replies report from url: #{wsdl_url}. SOAP body request: #{soap_body.inspect}"
      response = service.request(:pull_client_notification){ soap.body = soap_body }

      #<ClientNotification><Status>OK</Status><BatchSize>1</BatchSize><Messages><Message><Type>Notification</Type><PhoneNumber>0527718999</PhoneNumber><Network>052</Network><Status>2</Status><StatusDescription>Delivered</StatusDescription><CustomerMessageId></CustomerMessageId><CustomerParam></CustomerParam><SenderNumber>0545290862</SenderNumber><SegmentsNumber>1</SegmentsNumber><NotificationDate>13/03/2012 10:16:56</NotificationDate><SentMessage>test</SentMessage></Message></Messages></ClientNotification>
      #<ClientNotification><Status>OK</Status><BatchSize>0</BatchSize></ClientNotification>
      soap_xml = response.doc
      logger.debug "Received response xml: \n#{soap_xml}"
      soap_xml.remove_namespaces!

      xml = ::Nokogiri::XML(soap_xml.at_css('PullClientNotificationResult').text)
      
      # temporary convert hash, remove when new version is uploaded (talk to Zorik about it)
      mapper_status_text_to_integer = {'OK' => 1, 'Failed' => -1, 'BadUserNameOrPassword' => -2, 'UserNameNotExists' => -3, 'PasswordNotExists' => -4}
      response_status = xml.at_css('Status').text
      raise Smsim::Errors::GatewayError.new(501, "Response status '#{response_status}' is neither of #{mapper_status_text_to_integer.keys}", :xml => xml) unless mapper_status_text_to_integer.keys.include?(response_status)

      begin
        batch_size = Integer(xml.at_css('BatchSize').text)
      rescue Exception => e
        raise Smsim::Errors::GatewayError.new(502, e.message, :xml => xml)
      end

      response = OpenStruct.new({
                                  :status => mapper_status_text_to_integer[response_status],
                                  :batch_size => batch_size,
                                  :notifications => [],
                                  :replies => [],
                                  :errors => []
                                })

      if response.status == 1 && response.batch_size > 0 # parse report messages
        xml.css('Messages Message').each do |msg|
          begin
            type = msg.at_css('Type').text
            if type == 'Notification'
              response.notifications << Smsim::DeliveryNotificationsParser.parse_notification_values_hash(
                :gateway_status => msg.at_css('Status').text,
                :parts_count => msg.at_css('SegmentsNumber').text,
                :message_id => msg.at_css('CustomerMessageId').text,
                :phone => msg.at_css('PhoneNumber').text,
                :reply_to_phone => msg.at_css('SenderNumber').text,
                :reason_not_delivered => msg.at_css('StatusDescription').text,
                :completed_at => msg.at_css('NotificationDate').text
              )
            elsif type == 'MoMessage'
              response.replies << Smsim::SmsRepliesParser.parse_reply_values_hash(
                :phone => msg.at_css('PhoneNumber').text,
                :text => msg.at_css('SentMessage').text,
                :reply_to_phone => msg.at_css('SenderNumber').text,
                :received_at => msg.at_css('NotificationDate').text
              )
            else
              raise Smsim::GatewayError.new(510, "Unknown message type '#{type}'")
            end
          rescue Exception => e
            response.errors << {:xml => msg.to_xml, :error_message => e.message, :error => e}
          end
        end
      end

      logger.debug "Returning parsed response: #{response.inspect}"

      response
    end
  end
end