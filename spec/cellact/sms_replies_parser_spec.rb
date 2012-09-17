require 'spec_helper'

describe Cellact::SmsRepliesParser do
  let(:gateway){ Cellact::Gateway.new(:username => 'alex', :password => 'pass', :company => 'comp') }
  let(:parser){ gateway.sms_replies_parser }

  describe '#http_push' do
    let(:reply_values) { {'SENDER' => '+972541234567', 'CONTENT' => 'kak dila', 'TO' => '+972529992090', 'BLMJ' => '12345', 'DATE' => '20110801111506'} }
    let(:reply) { parser.http_push({'XMLString' => XmlResponseStubs.sms_reply_http_xml_string(reply_values)}) }

    it 'should raise DeliveryNotificationError if parameters are missing or not of expected type' do
      lambda { parser.http_push({'Puki' => 'asdf'}) }.should raise_error(Cellact::GatewayError)
    end

    it 'should return SmsReply with all fields initialized' do
      Time.stub(:now).and_return(Time.utc(2011, 8, 1, 11, 15, 06))

      reply.should be_present
      reply.message_id.should == '12345'
      reply.phone.should == '972541234567'
      reply.text.should == 'kak dila'
      reply.reply_to_phone.should == '972529992090'
      reply.received_at.strftime('%d/%m/%Y %H:%M:%S').should == '01/08/2011 11:15:06'
    end
  end

end
