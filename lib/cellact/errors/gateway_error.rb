module Cellact
  module Errors
    class GatewayError < StandardError

      # Error codes legend:
      # 400 group - connection problems
      #   400 - http bad request
      #   401 - http unauthorized
      #   402 - http forbidden
      #   404 - http url not found
      #   412 - BadUserNameOrPassword
      #   413 - UserNameNotExists
      #   114 - PasswordNotExists
      #   422 - UserBlocked
      #   426 - UserAuthenticationError
      #   450 - error on gateway server

      # 200 group - send sms message xml format errors
      #   206 - RecipientsDataNotExists
      #   209 - MessageTextNotExists
      #   211 - IllegalXML
      #   213 - UserQuotaExceeded
      #   214 - ProjectQuotaExceeded
      #   215 - CustomerQuotaExceeded
      #   216 - WrongDateTime
      #   218 - WrongRecipients
      #   220 - InvalidSenderNumber
      #   221 - InvalidSenderName
      #   228 - NetworkTypeNotSupported
      #   229 - NotAllNetworkTypesSupported
      #   250 - Gateway response xml is illegal

      # 300 group - delivery notification errors
      #    301 - missing http parameters
      #    302 - type conversion error

      # 500 group - pull reports errors
      #    501 - xml response status is invalid
      #    502 - type conversion error
      #    510 - unknown message type in report (neither notification on sms reply)
      #

      # 600 group - sms reply parsing errors
      #    601 - missing http push parameter
      #    602 - xml in http push is invalid
      #    603 - failed to convert received reply date
      #
      attr_reader :code, :more_info

      def initialize(code, message, more_info = {})
        @code = code
        @more_info = more_info
        super(message)
      end

      def self.map_send_sms_xml_response_status(xml_response_status)
        map = {
          100 => {-1 => 411, -2 => 412, -3 => 413, -4 => 414, -22 => 422, -26 => 426},
          200 => [-6, -9, -11, -13, -14, -15, -16, -18, -20, -21, -28, -29].inject({}){|h,key| h[key] = (key*-1)+200; h }
        }

        map.collect{|group, group_map| group_map[xml_response_status]}.compact.first
      end

    end
  end
end
