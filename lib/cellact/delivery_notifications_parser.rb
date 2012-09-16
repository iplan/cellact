require "savon"
require 'nokogiri'

module Cellact
  class DeliveryNotificationsParser
    attr_reader :logger, :gateway

    # Create new sms delivery notification parser with given +gateway+
    def initialize(gateway)
      @gateway = gateway
      @logger = Logging.logger[self.class]
    end

    # params will look something like the following:
    # {"CONFIRMATION"=>"<PALO><BLMJ>84bb6764-0cb5-4299-9a37-f0eac4bec088</BLMJ><SENDER>iPlan</SENDER><RECIPIENT MNP=\"97254\">+972545290862</RECIPIENT><FINAL_DATE>20120913112741</FINAL_DATE><EVT>mt_ok</EVT><MSG_ID></MSG_ID><REASON>5000</REASON><MESSAGE_COUNT>1</MESSAGE_COUNT>\n</PALO>"}
    def http_push(params)
      %w(CONFIRMATION).each do |p|
        raise Cellact::Errors::GatewayError.new(301, "Missing http parameter #{p}. Parameters were: #{params.inspect}", :params => params) if params[p].blank?
      end
      logger.debug "Parsing http push delivery notification params: #{params.inspect}"


      begin
        logger.debug "Parsing http push delivery notification xml: \n#{params['CONFIRMATION']}"
        doc = ::Nokogiri::XML(params['CONFIRMATION'])
        parse_notification_values_hash(
          :gateway_status => doc.at_css('EVT').text,
          :phone => doc.at_css('RECIPIENT').text,
          :message_id => doc.at_css('BLMJ').text,
          :parts_count => doc.at_css('MESSAGE_COUNT').text,
          :completed_at => doc.at_css('FINAL_DATE').text,
          :sender => doc.at_css('SENDER').text,
          :reason_not_delivered => doc.at_css('REASON').text
        )
      rescue Exception => e
        raise Cellact::Errors::GatewayError.new(602, "Failed to parse delivery notification push xml: #{e.message}", :xml => params['CONFIRMATION'])
      end
    end

    # This method receives notification +values+ Hash and tries to type cast it's values and determine delivery status (add delivered?)
    # @raises Cellact::Errors::GatewayError when values hash is missing attributes or when one of the attributes fails to be parsed
    #
    # Method returns object with the following attributes:
    # * +gateway_status+ - gateway status (string) value, either of: mt_ok, mt_nok, mt_del, mt_rej
    # * +delivery_status+ - :delivered, :failed or :unknown
    # * +parts_count+ - how many parts the sms was
    # * +completed_at+ - when the sms was delivered (as reported by network operator)
    # * +sender+ - the phone to sms reply will be sent when receiver replies to message or sender name for 1 way sms
    # * +message_id+ - gateway message id of the sms that was sent
    def parse_notification_values_hash(values)
      logger.debug "Parsing delivery notification values hash: #{values.inspect}"
      Time.zone = @gateway.time_zone
      [:gateway_status, :message_id, :parts_count, :completed_at, :sender].each do |key|
        raise Cellact::Errors::GatewayError.new(301, "Missing notification values key #{key}. Values were: #{values.inspect}", :values => values) if values[key].blank?
      end

      values[:phone] = PhoneNumberUtils.without_starting_plus(values[:phone])
      values[:sender] = PhoneNumberUtils.without_starting_plus(values[:sender])
      values[:delivery_status] = self.class.gateway_delivery_status_to_delivery_status(values[:gateway_status])

      begin
        values[:parts_count] = Integer(values[:parts_count])
      rescue Exception => e
        logger.error "MESSAGE_COUNT could not be converted to integer. MESSAGE_COUNT was: #{values[:parts_count]}. \n\t #{e.message}: \n\t #{e.backtrace.join("\n\t")}"
        raise Cellact::Errors::GatewayError.new(302, "MESSAGE_COUNT could not be converted to integer. MESSAGE_COUNT was: #{values[:parts_count]}", :values => values)
      end

      begin
        values[:completed_at] = DateTime.strptime(values[:completed_at], '%Y%m%d%H%M%S')
        values[:completed_at] = Time.zone.parse(values[:completed_at].strftime('%Y-%m-%d %H:%M:%S')) #convert to ActiveSupport::TimeWithZone
      rescue Exception => e
        logger.error "FINAL_DATE could not be converted to date. FINAL_DATE was: #{values[:completed_at]}. \n\t #{e.message}: \n\t #{e.backtrace.join("\n\t")}"
        raise Cellact::Errors::GatewayError.new(302, "FINAL_DATE could not be converted to date. FINAL_DATE was: #{values[:completed_at]}", :values => values)
      end

      OpenStruct.new(values)
    end

    def self.gateway_delivery_status_to_delivery_status(gateway_status)
      if gateway_status == 'mt_del'
        :delivered
      elsif gateway_status == 'mt_nok' || gateway_status == 'mt_rej'
        :failed
      else
        :unknown
      end
    end

  end
end
