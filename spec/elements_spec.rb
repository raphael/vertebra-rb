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

include Vertebra

describe 'Agent-related elements' do

  before do
    @agent_classes = [Authorization, Ack, Vertebra::Data, Operation, Res]
  end

  it 'have agent api xml namespace' do
    @agent_classes.each do |klass|
      element = klass.new
      element.attributes['xmlns'].should == 'http://xmlschema.engineyard.com/agent/api'
    end
  end

end
