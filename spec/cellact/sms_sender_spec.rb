require 'spec_helper'

describe Cellact::SmsSender do
  let(:gateway_config){ {:username => 'alex', :password => 'pass', :company => 'cmp'} }
  let(:gateway){ Cellact::Gateway.new(gateway_config) }
  let(:sender) { gateway.sms_sender }

  describe '#send_sms' do
    let(:message){ 'my message text' }
    let(:phone){ '972541234567' }

    it 'should raise error if text is blank' do
      lambda{ sender.send_sms('', phone) }.should raise_error(ArgumentError)
    end

    it 'should raise error if phone is blank' do
      lambda{ sender.send_sms(message, '') }.should raise_error(ArgumentError)
    end

    it 'should raise error if phone is not valid cellular phone' do
      lambda{ sender.send_sms(message, '0541234567') }.should raise_error(ArgumentError)
      lambda{ sender.send_sms(message, '541234567') }.should raise_error(ArgumentError)
    end

    it 'should raise error if sender_number is present and not valid cellular phone' do
      lambda{ sender.send_sms(message, phone, :sender_number => '0541234567') }.should raise_error(ArgumentError)
      lambda{ sender.send_sms(message, phone, :sender_number => '541234567') }.should raise_error(ArgumentError)
    end

    it 'should raise error if sender_name is present and not latin characters' do
      lambda{ sender.send_sms(message, phone, :sender_name => '0541234567') }.should raise_error(ArgumentError)
      lambda{ sender.send_sms(message, phone, :sender_name => '*7') }.should raise_error(ArgumentError)
      lambda{ sender.send_sms(message, phone, :sender_name => 'יוסי') }.should raise_error(ArgumentError)
    end

    it 'should raise error when send failed' do
      XmlResponseStubs.stub_request_with_sms_send_response(self, sender.wsdl_url, :result => false)
      lambda{ sender.send_sms('message', phone, :sender_number => '972541234567') }.should raise_error(Cellact::Errors::GatewayError)
    end

    it 'should return message_id when send succeeds' do
      XmlResponseStubs.stub_request_with_sms_send_response(self, sender.wsdl_url, :result => true, :sessionId => 1234)
      result = sender.send_sms('message', phone, :sender_number => '972541234567')
      result.message_id.should == '1234'
    end

    it 'should return sender_number, sender_name and sender when send succeeds' do
      XmlResponseStubs.stub_request_with_sms_send_response(self, sender.wsdl_url, :result => true, :sessionId => 1234)
      result = sender.send_sms('message2', phone, :sender_number => '972541234567', :sender_name => 'puki')
      result.sender_number.should == '972541234567'
      result.sender_name.should == 'puki'
    end
  end

  describe '#build_soap_body' do
    let(:message){ 'my message text' }
    let(:phones){ ['972541234567'] }
    let(:opts){ {:sender_number => '972541234567'} }
    let(:soap_body_hash){ sender.build_soap_body_hash(message, phones, opts) }

    it 'should have username, password and company' do
      soap_body_hash['credentials']['username'].should == 'alex'
      soap_body_hash['credentials']['password'].should == 'pass'
      soap_body_hash['credentials']['company'].should == 'cmp'
    end

    it 'should have message text' do
      soap_body_hash['sendRequest']['content'].should.should == message
    end

    it 'should have recipients phone number' do
      soap_body_hash['sendRequest']['destinationAddresses'].size.should == 1
      soap_body_hash['sendRequest']['destinationAddresses'].first['DestinationAddress']['address'].should == "+#{phones.first}"
    end

    it 'should have all recipients phone numbers' do
      phones << '0541234568' << '0541234569'
      soap_body_hash['sendRequest']['destinationAddresses'].size.should == 3
      phones.each do |p|
        soap_body_hash['sendRequest']['destinationAddresses'].select{|da| da['DestinationAddress']['address'] == "+#{p}" }.size.should == 1
      end
    end

    it 'should have gateway sender number' do
      soap_body_hash['sendRequest']['sender'].should == opts[:sender_number]
    end

    it 'should have gateway sender_name even if sender_number present' do
      opts[:sender_name] = 'puki'
      soap_body_hash['sendRequest']['sender'].should == opts[:sender_name]
    end

    it 'should have delivery notification url if specified' do
      opts[:delivery_notification_url] = 'http://google.com?auth=1234&alex=king'
      soap_body_hash['deliveryAddresses']['DeliveryReportAddress']['type'].should == 'http'
      soap_body_hash['deliveryAddresses']['DeliveryReportAddress']['address'].should == 'http://google.com?auth=1234&alex=king'
    end

    it 'should not have delivery notification url if not specified' do
      soap_body_hash['deliveryAddresses'].should be_nil
    end
  end

  describe '#parse_response_xml' do
    it 'should return error description when send fails' do
      xml = XmlResponseStubs.send_sms_response(:result => false, :errorDescription => 'not good')
      result = sender.parse_response_xml(xml)
      result.ok.should be_false
      result.error_description.should == 'not good'
    end

    it 'should return message_id when send succeeds' do
      xml = XmlResponseStubs.send_sms_response(:result => true, :sessionId => 3333)
      result = sender.parse_response_xml(xml)
      result.ok.should be_true
      result.message_id.should == '3333'
    end
  end

end
