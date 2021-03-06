# Copyright 2008, Engine Yard, Inc.
#
# This file is part of Vertebra.
#
# Vertebra is free software: you can redistribute it and/or modify it under the
# terms of the GNU Lesser General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option) any
# later version.
#
# Vertebra is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for more
# details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with Vertebra.  If not, see <http://www.gnu.org/licenses/>.

require File.dirname(__FILE__) + '/spec_helper'
require 'vertebra'
require 'vertebra/agent'
require 'vertebra/synapse_queue'

# Specs to test the protocol portion of Vertebra.

describe Vertebra::Op do

  it 'should allow initialization with an array' do
    op = Vertebra::Op.new('/testop',"/test/test")
    op.should be_kind_of(Vertebra::Op)
    op.instance_variable_get('@op_type').should be_kind_of(Vertebra::Resource)
    op.instance_variable_get('@op_type').to_s.should == '/testop'
    op.instance_variable_get('@args')['/test/test'].should be_kind_of(Vertebra::Resource)
    op.instance_variable_get('@args')['/test/test'].to_s.should == '/test/test'
  end

  it 'should allow initialization with a hash' do
    op = Vertebra::Op.new('/testop',{'from' => '/george', 'to' => '/man/in/yellow/hat'})
    op.should be_kind_of(Vertebra::Op)
    op.instance_variable_get('@op_type').should be_kind_of(Vertebra::Resource)
    op.instance_variable_get('@op_type').to_s.should == '/testop'
    op.instance_variable_get('@args')['from'].should == '/george'
    op.instance_variable_get('@args')['to'].should == '/man/in/yellow/hat'
  end

  it 'should allow initialization with an array and a hash' do
    op = Vertebra::Op.new('/testop',"/test/test",{'from' => '/george', 'to' => '/man/in/yellow/hat'})
    op.should be_kind_of(Vertebra::Op)
    op.instance_variable_get('@op_type').should be_kind_of(Vertebra::Resource)
    op.instance_variable_get('@op_type').to_s.should == '/testop'
    op.instance_variable_get('@args')['/test/test'].should be_kind_of(Vertebra::Resource)
    op.instance_variable_get('@args')['/test/test'].to_s.should == '/test/test'
    op.instance_variable_get('@op_type').should be_kind_of(Vertebra::Resource)
    op.instance_variable_get('@op_type').to_s.should == '/testop'
    op.instance_variable_get('@args')['from'].should == '/george'
    op.instance_variable_get('@args')['to'].should == '/man/in/yellow/hat'
  end

  # todo: write a decent test of #to_iq

end

class Mock
  attr_accessor :deja_vu_map

  def initialize
    @deja_vu_map = {}
    yield(self) if block_given?
  end

  def def(symbol, &block)
    self.class.class_eval do
      define_method symbol, &block
    end
  end
end

describe Vertebra::Protocol::Client do
  AGENT_JID = "agent@example.com"
  REMOTE_JID = "test@example.com"

  before :each do
    @synapses = synapses = Vertebra::SynapseQueue.new
    @agent = Mock.new do |mock|
      mock.def(:connection_is_open_and_authenticated?) {true}
      mock.def(:defer_on_busy_jid?) {|jid| true}
      mock.def(:jid) {AGENT_JID}
      mock.def(:remove_busy_jid) {|jid, client| }
      mock.def(:remove_client) {|token| }
      mock.def(:send_iq) {|iq| }
      mock.def(:set_busy_jid) {|jid, client| }
      mock.def(:add_client) {|token, client| }
      mock.def(:enqueue_synapse) {|synapse| synapses << synapse}
      mock.def(:parse_token) {|node| }
    end

    @op = Vertebra::Op.new("/foo")
    @to = "to@localhost"
    @client = Vertebra::Protocol::Client.start(@agent, @op, @to)
  end

  it 'Should enqueue a synapse during initialization' do
    @client.state.should == :new
    @synapses.size.should == 1
  end

  it 'Should defer if connection is not open and authenticated' do
    synapse = @synapses.first

    @agent.def(:connection_is_open_and_authenticated?) {:deferred}
    @synapses.fire
    @synapses.size.should == 1
    @synapses.first.should == synapse
  end

  it 'Should defer if there is another IQ in progress to the same jid' do
    synapse = @synapses.first

    @agent.def(:defer_on_busy_jid?) {|jid| :deferred}
    @synapses.fire
    @synapses.first.should == synapse
  end

  it 'Should send an IQ' do
    synapse = @synapses.first

    actual_iq = nil
    @agent.def(:send_iq) {|iq| actual_iq = iq}

    2.times { @synapses.fire }

    expected_iq = @op.to_iq(@to, AGENT_JID)
    # The nodes have different 'id' attributes until I set them. I'm not
    # worried about what the 'id' is, so I'm just going to make sure they're
    # equal.
    iq_id = actual_iq.node.get_attribute('id')
    expected_iq.node.set_attribute('id', iq_id)

    actual_iq.node.to_s.should == expected_iq.node.to_s
  end

  def create_iq
    iq = LM::Message.new(REMOTE_JID, LM::MessageType::IQ)
    iq.node.set_attribute('id', '42')
    iq.node.set_attribute('xml:lang','en')
    iq.node.set_attribute('type', 'set')
    iq
  end

  def create_incoming_iq
    iq = create_iq
    iq.node.set_attribute('to', AGENT_JID)
    iq.node.set_attribute('from', REMOTE_JID)
    iq
  end

  def create_response_iq
    iq = create_iq
    iq.node.set_attribute("to", REMOTE_JID)
    iq.node.set_attribute('type', 'result')
    iq
  end

  def do_stanza(method, type)
    iq = create_incoming_iq
    stanza = iq.node.add_child(type.to_s)
    yield(stanza) if block_given?

    @client.send(method, iq, type, stanza)
    actual_iq = nil, @agent.def(:send_iq) {|x| actual_iq = x}
    @synapses.fire

    expected_iq = create_response_iq
    expected_iq.node.raw_mode = true
    expected_iq.node.value = stanza
    actual_iq.node.to_s.should == expected_iq.node.to_s
  end

  it 'Should respond to a nack when in the ready state' do
    @synapses.clear
    @client.instance_eval { @state = :ready }
    do_stanza(:process_ack_or_nack, :nack)
    @client.state.should == :authfail
  end

  it 'Should respond to an ack when in the ready state' do
    @synapses.clear
    @client.instance_eval { @state = :ready }
    do_stanza(:process_ack_or_nack, :ack)
    @client.state.should == :consume
  end

  it 'Should respond to a result when in the consume state' do
    @synapses.clear
    @client.instance_eval { @state = :consume}
    do_stanza(:process_data_or_final, :result)
    @client.state.should == :consume
  end

  it 'Should respond to an error when in the consume state' do
    @synapses.clear
    @client.instance_eval { @state = :consume }
    do_stanza(:process_data_or_final, :error)
    @client.state.should == :error
  end

  it 'Should respond to an final when in the consume state' do
    @synapses.clear
    @client.instance_eval { @state = :consume }
    do_stanza(:process_data_or_final, :final)
    @client.state.should == :commit
  end
end

describe Vertebra::Protocol::Server do

end
