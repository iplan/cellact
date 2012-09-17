require 'active_support/all'

%w{phone_number_utils   gateway   sms_sender   delivery_notifications_parser   sms_replies_parser   gateway_error}.each do |file_name|
  require File.join(File.dirname(__FILE__), 'cellact', file_name)
end

module Cellact

end
