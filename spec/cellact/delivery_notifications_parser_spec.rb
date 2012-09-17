require 'spec_helper'

describe Cellact::DeliveryNotificationsParser do
  let(:gateway){ Cellact::Gateway.new({:username => 'alex', :password => 'pass', :company => 'cmp'}) }
  let(:parser) { gateway.delivery_notification_parser }

  describe '#http_push' do
    let(:notification_values) { {'BLMJ' => 1113333, 'SENDER' => '+972541234567', 'RECIPIENT' => '+97254290862', 'FINAL_DATE' => '20110801111500', 'EVT' => 'mt_del', 'MESSAGE_COUNT' => 3} }
    let(:notification) { parser.http_push({'CONFIRMATION' => XmlResponseStubs.delivery_notification_http_xml_string(notification_values)}) }

    it 'should raise error if parameters are missing or not of expected type' do
      lambda { parser.http_push({'Puki' => 'asdf'}) }.should raise_error(Cellact::GatewayError)
    end

    it 'should return delivery notification with all fields initialized' do
      Time.stub(:now).and_return(Time.utc(2011, 8, 1, 11, 15, 00))

      notification.should be_present
      notification.gateway_status.should == 'mt_del'
      notification.phone.should == '97254290862'
      notification.message_id.should == '1113333'
      notification.sender.should == '972541234567'
      notification.completed_at.strftime('%d/%m/%Y %H:%M:%S').should == '01/08/2011 11:15:00'
      notification.parts_count.should == 3
    end
  end

end
