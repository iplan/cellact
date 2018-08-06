require 'spec_helper'

describe Cellact::PhoneNumberUtils do
  let(:utils) { Cellact::PhoneNumberUtils }

  describe '#valid_cellular_phone?' do
    it 'should not be valid without country code' do
      utils.valid_cellular_phone?('0545290862').should be_falsy
    end

    it 'should not be valid for landline phones' do
      utils.valid_cellular_phone?('035447037').should be_falsy
      utils.valid_cellular_phone?('97235447037').should be_falsy
    end

    it 'should not be valid with country code but of different lenth' do
      utils.valid_cellular_phone?('9725452908622').should be_falsy
      utils.valid_cellular_phone?('97254529086').should be_falsy
    end

    it 'should be valid with country code' do
      utils.valid_cellular_phone?('972545290862').should be_truthy
    end
  end

  describe '#valid_land_line_phone?' do
    it 'should not be valid without country code' do
      utils.valid_land_line_phone?('031234567').should be_falsy
    end

    it 'should be valid with country code' do
      utils.valid_land_line_phone?('97231234567').should be_truthy
      utils.valid_land_line_phone?('972771234567').should be_truthy
    end
  end

end
