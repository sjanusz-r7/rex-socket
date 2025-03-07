# -*- coding:binary -*-
require 'rex/socket/range_walker'
require 'spec_helper'

RSpec.describe Rex::Socket do

  describe '.addr_itoa' do

    context 'with explicit v6' do
      it "should convert a number to a human-readable IPv6 address" do
        expect(described_class.addr_itoa(1, true)).to eq "::1"
      end
    end

    context 'with explicit v4' do
      it "should convert a number to a human-readable IPv4 address" do
        expect(described_class.addr_itoa(1, false)).to eq "0.0.0.1"
      end
    end

    context 'without explicit version' do
      it "should convert a number within the range of possible v4 addresses to a human-readable IPv4 address" do
        expect(described_class.addr_itoa(0)).to eq "0.0.0.0"
        expect(described_class.addr_itoa(1)).to eq "0.0.0.1"
        expect(described_class.addr_itoa(0xffff_ffff)).to eq "255.255.255.255"
      end
      it "should convert a number larger than possible v4 addresses to a human-readable IPv6 address" do
        expect(described_class.addr_itoa(0xfe80_0000_0000_0000_0000_0000_0000_0001)).to eq "fe80::1"
        expect(described_class.addr_itoa(0x1_0000_0001)).to eq "::1:0:1"
      end
    end

  end

  describe '.addr_aton' do
    subject(:nbo) do
      described_class.addr_aton(try)
    end

    context 'with ipv6' do
      let(:try) { "fe80::1" }
      it { is_expected.to be_an(String) }
      it { expect(subject.bytes.count).to eq(16) }
      it "should be in the right order" do
        expect(nbo).to eq "\xfe\x80\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01"
      end
    end

    context 'with ipv4' do
      let(:try) { "127.0.0.1" }
      it { is_expected.to be_an(String) }
      it { expect(subject.bytes.count).to eq(4) }
      it "should be in the right order" do
        expect(nbo).to eq "\x7f\x00\x00\x01"
      end
    end

    context 'with a hostname' do
      let(:try) { "localhost" }
      it "should resolve" do
        expect(nbo).to be_a(String)
        expect(nbo.encoding).to eq Encoding.find('binary')
        expect([ 4, 16 ]).to include(nbo.length)
      end
    end

  end

  describe '.compress_address' do

    subject(:compressed) do
      described_class.compress_address(try)
    end

    context 'with lots of single 0s' do
      let(:try) { "fe80:0:0:0:0:0:0:1" }
      it { is_expected.to eq "fe80::1" }
    end

  end

  describe '.getaddress' do

    subject { described_class.getaddress('whatever') }

    before(:example) do
      allow(Addrinfo).to receive(:getaddrinfo).and_return(response_addresses.map {|address| Addrinfo.ip(address)})
    end

    context 'when ::Addrinfo.getaddrinfo returns IPv4 responses' do
      let(:response_afamily) { Socket::AF_INET }
      let(:response_addresses) { ["1.1.1.1", "2.2.2.2"] }

      it { is_expected.to be_a(String) }
      it "should return the first ASCII address" do
        expect(subject).to eq "1.1.1.1"
      end
    end

    context 'when ::Addrinfo.getaddrinfo returns IPv6 responses' do
      let(:response_afamily) { Socket::AF_INET6 }
      let(:response_addresses) { ["fe80::1", "fe80::2"] }

      it { is_expected.to be_a(String) }
      it "should return the first ASCII address" do
        expect(subject).to eq "fe80::1"
      end
    end
  end

  describe '.getaddresses' do

    let(:accepts_ipv6) { true }
    subject { described_class.getaddresses('whatever', accepts_ipv6) }

    before(:example) do
      allow(Addrinfo).to receive(:getaddrinfo).and_return(response_addresses.map {|address| Addrinfo.ip(address)})
    end

    context 'when ::Addrinfo.getaddrinfo returns IPv4 responses' do
      let(:response_afamily) { Socket::AF_INET }
      let(:response_addresses) { ["1.1.1.1", "2.2.2.2"] }

      it { is_expected.to be_an(Array) }
      it { expect(subject.size).to eq(2) }
      it "should return the ASCII addresses" do
        expect(subject).to include("1.1.1.1")
        expect(subject).to include("2.2.2.2")
      end
    end

    context 'when ::Addrinfo.getaddrinfo returns IPv6 responses' do
      context "when accepts_ipv6 is true" do
        let(:accepts_ipv6) { true }
        let(:response_afamily) { Socket::AF_INET6 }
        let(:response_addresses) { ["fe80::1", "fe80::2"] }

        it { is_expected.to be_an(Array) }
        it { expect(subject.size).to eq(2) }
        it "should return the ASCII addresses" do
          expect(subject).to include("fe80::1")
          expect(subject).to include("fe80::2")
        end
      end

      context "when accepts_ipv6 is false" do
        let(:accepts_ipv6) { false }
        let(:response_afamily) { Socket::AF_INET6 }
        let(:response_addresses) { ["fe80::1", "fe80::2"] }

        it { is_expected.to be_an(Array) }
        it { expect(subject).to be_empty }
      end
    end
  end

  describe '.portspec_to_portlist' do

    subject(:portlist) { described_class.portspec_to_portlist portspec_string}
    let(:portspec_string) { '-1,0-10,!2-5,!7,65530-,65536' }

    it 'does not include negative numbers' do
      expect(portlist).to_not include '-1'
    end

    it 'does not include 0' do
      expect(portlist).to_not include '0'
    end

    it 'does not include negated numbers' do
      ['2', '3', '4', '5', '7'].each do |port|
        expect(portlist).to_not include port
      end
    end

    it 'does not include any numbers above 65535' do
      expect(portlist).to_not include '65536'
    end

    it 'expands open ended ranges' do
      (65530..65535).each do |port|
        expect(portlist).to include port
      end
    end
  end

  describe '.is_ipv4?' do
    subject(:addr) do
      described_class.is_ipv4?(try)
    end

    context 'with an IPv4 address' do
      let(:try) { '0.0.0.0' }
      it 'should return true' do
        expect(addr).to eq true
      end
    end

    context 'with an IPv6 address' do
      let(:try) { '::1' }
      it 'should return false' do
        expect(addr).to eq false
      end
    end

   context 'with a hostname' do
      let(:try) { "localhost" }
      it "should return false" do
        expect(addr).to eq false
      end
   end

    context 'with nil' do
      let(:try) { nil }
      it "should return false" do
        expect(addr).to eq false
      end
    end
  end

  describe '.is_ipv6?' do
    subject(:addr) do
      described_class.is_ipv6?(try)
    end

    context 'with an IPv4 address' do
      let(:try) { '0.0.0.0' }
      it 'should return false' do
        expect(addr).to eq false
      end
    end

    context 'with an IPv6 address' do
      let(:try) { '::' }
      it 'should return true' do
        expect(addr).to eq true
      end
    end

    context 'with a hostname' do
      let(:try) { "localhost" }
      it "should return false" do
        expect(addr).to eq false
      end
    end

    context 'with nil' do
      let(:try) { nil }
      it "should return false" do
        expect(addr).to eq false
      end
    end
  end
end
