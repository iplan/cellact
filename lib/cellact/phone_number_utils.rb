module Cellact

  class PhoneNumberUtils
    @@valid_lengths = {
      :cellular => '545123456'.length,
      :land_line => ['31235678'.length, '777078406'.length]
    }
    @@country_code = '972'

    # this method adds 972 country code to given phone if needed
    # if phone is blank --> doesn't change it
    def self.ensure_country_code(phone)
      if !phone.blank? && !phone.start_with?(@@country_code)
        phone = phone[1..phone.size] if phone.start_with?('0')
        phone = "972#{phone}"
      end
      phone
    end

    def self.without_country_code(phone)
      phone.start_with?('972') ? phone.gsub('972', '0') : phone
    end

    # validates that given phone is Israeli cellular format with country code: 972545123456
    def self.valid_cellular_phone?(phone)
      valid_phone_length?(phone, @@valid_lengths[:cellular])
    end

    # validates that given phone is Israeli landline format with country code: 972545123456
    def self.valid_land_line_phone?(phone)
      valid_phone_length?(phone, @@valid_lengths[:land_line].first) || valid_phone_length?(phone, @@valid_lengths[:land_line].last)
    end

    # valid sender number is between 4 and 14 digits
    def self.valid_sender_number?(sender_number)
      sender_number =~ /^[0-9]{4,14}$/i
    end

    # valid sender name is between 2 and 11 latin chars or digits
    def self.valid_sender_name?(sender_name)
      sender_name =~ /^[a-z0-9]{2,11}$/i
    end

    # make sure phone is in given length and starts with country code
    def self.valid_phone_length?(phone, length)
      phone = phone.to_s
      phone.start_with?(@@country_code) && phone =~ /^#{@@country_code}[0-9]{#{length}}$/
    end

    # this method will convert given phone number to base 36 string if phone contains digits only
    # if phone contains digits and letters it will leave it untouched
    def self.phone_number_to_id_string(phone)
      phone = phone.to_i.to_s(36) if phone =~ /^[0-9]+$/
      phone
    end

    def self.without_starting_plus(phone)
      phone = phone[1, phone.length] if phone.start_with?('+')
      phone
    end
  end

end