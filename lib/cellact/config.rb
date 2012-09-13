require 'ostruct'
module Cellact

  def self.config
    @@configuration ||= OpenStruct.new({
      :urls => {
        :send_sms => 'http://la1.cellactpro.com/SendSms.asmx',
      },
      :time_zone => 'Jerusalem'
    })
    @@configuration
  end
  
end