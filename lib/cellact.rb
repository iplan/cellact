require 'active_support/all'

%w{phone_number_utils   gateway   sms_sender   delivery_notifications_parser}.each do |file_name|
  require File.join(File.dirname(__FILE__), 'cellact', file_name)
end

%w{gateway_error}.each do |file_name|
  require File.join(File.dirname(__FILE__), 'cellact', 'errors', file_name)
end

module Cellact

end
