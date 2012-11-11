require 'nokogiri'

module Cellact
  class SmsRepliesParser
    attr_reader :logger, :gateway

    # Create new sms delivery notification parser with given +gateway+
    def initialize(gateway)
      @gateway = gateway
      @logger = Logging.logger[self.class]
    end

    # params will look something like the following:
    # { "XMLString" => "<PALO>
    #                     <HEAD>
    #                       <BLMJ>588971c4-ab8f-4940-ba4d-e2745b6d2aea</BLMJ>
    #                       <CMD>היי</CMD>
    #                       <COMPANY>iplan</COMPANY>
    #                     </HEAD>
    #                     <BODY>
    #                       <SENDER OP=\"97254\" NET=\"GSM\" DEVICE_MODEL=\"\">+972545290862</SENDER>
    #                       <CONTENT>היי לך</CONTENT>
    #                       <DEST_LIST>
    #                         <TO>+972529999299</TO>
    #                       </DEST_LIST>
    #                     </BODY>
    #                     <OTHER>
    #                       <EVT>mo</EVT>
    #                       <DATE>20120916125254</DATE>
    #                       <CP_MO>cellcom</CP_MO>
    #                     </OTHER>
    #                   </PALO>" }
    # BLMJ - incoming message id in gateway
    # SENDER - the number of person who replied to sms
    # CONTENT - text of the message
    # TO - number to which reply was sent (0529992090)
    # DATE - date on which the incoming sms was received at gateway
    def http_push(params)
      %w(XMLString).each do |p|
        raise Cellact::GatewayError.new(601, "Missing http parameter #{p}. Parameters were: #{params.inspect}", :params => params) if params[p].blank?
      end

      begin
        logger.debug "Parsing http push reply xml: \n#{params['XMLString']}"
        doc = ::Nokogiri::XML(params['XMLString'])
        parse_reply_values_hash(
          :message_id => doc.at_css('PALO  HEAD  BLMJ').text,
          :phone => doc.at_css('PALO  BODY  SENDER').text,
          :text => doc.at_css('PALO  BODY  CONTENT').text,
          :reply_to_phone => doc.at_css('PALO  BODY  DEST_LIST  TO').text,
          :received_at => doc.at_css('PALO  OTHER  DATE').text
        )
      rescue Exception => e
        raise Cellact::GatewayError.new(602, "Failed to parse reply push xml: #{e.message}", :xml => params['IncomingXML'])
      end
    end

    # This method receives sms reply +values+ Hash and tries to type cast it's values
    # @raises Cellact::GatewayError when values hash is missing attributes or when one of attributes fails to be type casted
    #
    # Method returns object with the following attributes:
    # * +phone+ - the phone that sent the sms (from which sms reply was received)
    # * +text+ - contents of the message that were received
    # * +reply_to_phone+ - the phone to sms which reply was sent (gateway phone number)
    # * +received_at+ - when the sms was received (as reported by gateway server)
    # * +message_id+ - uniq message id generated from phone,reply_to_phone and received_at timestamp
    def parse_reply_values_hash(values)
      logger.debug "Parsing reply_values_hash: #{values.inspect}"
      Time.zone = @gateway.time_zone
      [:phone, :reply_to_phone, :message_id].each do |key| #NOTE!!! we allow text to be blank, as it can be blank (it should be handled in the app layer)
        raise Cellact::GatewayError.new(601, "Missing sms reply values key #{key}. Values were: #{values.inspect}", :values => values) if values[key].blank?
      end

      values[:phone] = PhoneNumberUtils.without_starting_plus(values[:phone])
      values[:reply_to_phone] = PhoneNumberUtils.without_starting_plus(values[:reply_to_phone])

      if values[:received_at].is_a?(String)
        begin
          received_at = DateTime.strptime(values[:received_at], '%Y%m%d%H%M%S')
          values[:received_at] = Time.zone.parse(received_at.strftime('%Y-%m-%d %H:%M:%S')) #convert to ActiveSupport::TimeWithZone
        rescue Exception => e
          logger.warn "Failed to convert :received_at to date object. received_at was: #{values[:received_at]}. \n\t #{e.message}: \n\t #{e.backtrace.join("\n\t")}"
          values[:received_at] = nil
        end
      end
      values[:received_at] ||= Time.now
      OpenStruct.new(values)
    end

  end
end
