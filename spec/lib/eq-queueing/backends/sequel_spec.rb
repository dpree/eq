require 'spec_helper'

describe EQ::Queueing::Backends::Sequel do
  subject { EQ::Queueing::Backends::Sequel.new }
  it_behaves_like 'abstract queue'
  it_behaves_like 'queue backend'

  it 'handles ::Sequel::DatabaseError with retry' do
    db_method = subject.instance_eval('method(:jobs)')
    raised = false
    subject.stub(:jobs).and_return do |arg|
      if raised
        db_method.call
      else
        raised = true
        raise ::Sequel::DatabaseError, "failed"
      end
    end
    subject.size.should == 0
    subject.push "foo"
    subject.size.should == 1
  end
end
