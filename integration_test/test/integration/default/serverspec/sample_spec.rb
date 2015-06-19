require 'spec_helper'

describe "Nothing" do
  describe file('/tmp') do
    it { should be_directory }
  end
end