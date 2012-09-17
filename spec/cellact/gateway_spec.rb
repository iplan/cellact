require 'spec_helper'

describe Cellact::Gateway do
  let(:options){ {:username => 'user', :password => 'pass', :company => 'comp'} }
  let(:gateway){ Cellact::Gateway.new(options) }

  context "when creating" do
    it 'should raise ArgumentError if username, password or company are blank' do
      lambda{ Cellact::Gateway.new(options.update(:username => '')) }.should raise_error(ArgumentError)
      lambda{ Cellact::Gateway.new(options.update(:password => '')) }.should raise_error(ArgumentError)
      lambda{ Cellact::Gateway.new(options.update(:company => '')) }.should raise_error(ArgumentError)
    end

    it 'should create gateway with given user and password and company' do
      g = Cellact::Gateway.new(options)
      g.username.should == options[:username]
      g.password.should == options[:password]
      g.company.should == options[:company]
    end
  end

  describe '#send_sms' do
    let(:g){ Cellact::Gateway.new(options) }

    before :each do
      XmlResponseStubs.stub_request_with_sms_send_response(self, g.cellact_urls[:send_sms], :result => true, :sessionId => '12345')
    end

    it 'should return generated message info with message_id when send succeeds' do
      result = g.send_sms('alex is king', '972541234567', :sender_number => '972541234567')
      result.should be_present
      result.message_id.should == '12345'
    end
  end

end
