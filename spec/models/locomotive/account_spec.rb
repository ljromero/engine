require 'spec_helper'

describe Locomotive::Account do
  let!(:existing_account) { FactoryGirl.create(:account, email: 'another@email.com') }

  it 'has a valid factory' do
    FactoryGirl.build(:account).should be_valid
  end

  ## Validations ##
  it { should validate_presence_of :name }
  it { should validate_presence_of :email }
  it { should validate_presence_of :password }
  it { should validate_uniqueness_of(:email).with_message(/is already taken/) }
  it { should allow_value('valid@email.com').for(:email) }
  it { should allow_value('prefix+suffix@email.com').for(:email) }
  it { should_not allow_value('not-an-email').for(:email) }

  it "has a default locale" do
    account = Locomotive::Account.new
    account.locale.should == 'en'
  end

  it "validates the uniqueness of email" do
    FactoryGirl.create(:account)
    (account = FactoryGirl.build(:account)).should_not be_valid
    account.errors[:email].should == ["is already taken"]
  end

  ## Associations ##

  it 'owns many sites' do
    account = FactoryGirl.create(:account)
    site_1  = FactoryGirl.create(:site, memberships: [Locomotive::Membership.new(account: account)])
    site_2  = FactoryGirl.create(:site, subdomain: 'another_one', memberships: [Locomotive::Membership.new(account: account)])
    sites   = [site_1, site_2].map(&:_id)
    account.reload.sites.all? { |s| sites.include?(s._id) }.should be_true
  end

  describe 'deleting' do

    before(:each) do
      @account = FactoryGirl.build(:account)
      @site_1 = FactoryGirl.build(:site,memberships: [FactoryGirl.build(:membership, account: @account)])
      @site_2 = FactoryGirl.build(:site,memberships: [FactoryGirl.build(:membership, account: @account)])
      @account.stubs(:sites).returns([@site_1, @site_2])
      Locomotive::Site.any_instance.stubs(:save).returns(true)
    end

    it 'also deletes memberships' do
      Locomotive::Site.any_instance.stubs(:admin_memberships).returns(['junk', 'dirt'])
      @site_1.memberships.first.expects(:destroy)
      @site_2.memberships.first.expects(:destroy)
      @account.destroy
    end

    it 'raises an exception if account is the only remaining admin' do
      @site_1.memberships.first.stubs(:admin?).returns(true)
      @site_1.stubs(:admin_memberships).returns(['junk'])
      lambda {
        @account.destroy
      }.should raise_error(Exception, "One admin account is required at least")
    end

  end

  describe '#super_admin?' do

    let(:account) { FactoryGirl.build(:account, super_admin: true) }
    subject { account.super_admin? }

    it { should be_true }

    context 'by default' do

      let(:account) { FactoryGirl.build(:account) }
      it { should be_false }

    end

  end

  describe '#local_admin?' do

    let(:role)        { 'admin' }
    let(:account)     { FactoryGirl.create(:account) }
    let(:membership)  { Locomotive::Membership.new(account: account, role: role) }
    let!(:site)       { FactoryGirl.create(:site, memberships: [membership]) }

    subject { account.local_admin? }

    context 'she/he is an admin for the site' do

      it { should be_true }

    end

    context 'she/he is an author for the site' do

      let(:role) { 'author' }
      it { should be_false }

    end

  end

  describe 'api_key' do

    let(:account) { FactoryGirl.build(:account) }

    it 'is not nil for a new account (after validation)' do
      account.valid?
      account.api_key.should_not be_nil
    end

    it 'can be regenerated over and over' do
      key_1 = account.regenerate_api_key
      key_1.should_not be_nil
      account.regenerate_api_key.should_not == key_1
    end

  end

end
