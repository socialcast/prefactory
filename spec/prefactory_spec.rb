# encoding: UTF-8

# Copyright (c) 2014, VMware, Inc. All Rights Reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do
# so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'spec_helper'

describe Prefactory do

  describe "#in_before_all?" do
    before(:all) do
      @in_before_all = in_before_all?
    end
    before(:each) do
      @in_before_each = in_before_all?
    end
    it "is only true when called inside a before(:all)" do
      expect(@in_before_all).to be_truthy
      expect(@in_before_each).to be_falsey
      expect(in_before_all?).to be_falsey # in this it-block context
    end
    after(:each) do
      flunk if in_before_all?
    end
    after(:all) do
      flunk if in_before_all?
    end
  end

  describe "location metadata" do
    context "with no other user metadata" do
      it do
        expect(RSpec.current_example.metadata[:location]).to include "prefactory_spec.rb"
        expect(RSpec.current_example.metadata[:example_group][:location]).to include "prefactory_spec.rb"
      end
    end
    context "with other user metadata", :foo => :bar, :baz => :bop do
      it do
        expect(RSpec.current_example.metadata[:location]).to include "prefactory_spec.rb"
        expect(RSpec.current_example.metadata[:example_group][:location]).to include "prefactory_spec.rb"
        expect(RSpec.current_example.metadata[:foo]).to eq(:bar)
        expect(RSpec.current_example.metadata[:baz]).to eq(:bop)
      end
    end
  end

  describe "#prefactory_add" do

    context "when passing a block with no FactoryGirl activity" do
      before :all do
        prefactory_add(:my_blog) do
          Blog.create! :title => 'My Blog'
        end
      end
      it "creates an object using the provided name" do
        expect(my_blog).to be_present
        expect(my_blog.title).to eq('My Blog')
        expect(my_blog.id).to be_present
        expect(Blog.where(:id => my_blog.id)).to exist
        expect(prefactory(:my_blog)).to eq(my_blog)
        expect(my_blog.counter).to be_nil
      end
    end

    context "when passing just a FactoryGirl factory name" do
      before :all do
        prefactory_add :blog
      end
      it "creates an object based on the factory name, via FactoryGirl::Syntax::Methods" do
        expect(blog).to be_present
        expect(blog.title).to match(/\ATitle [0-9]+\z/)
        expect(blog.id).to be_present
        expect(Blog.where(:id => blog.id)).to exist
        expect(prefactory(:blog)).to eq(blog)
        expect(blog.counter).to be_nil
      end
    end
    context "when passing a factory name and additional attributes" do
      before :all do
        prefactory_add :blog, :counter => 12
      end
      it "uses the additional attributes" do
        expect(blog).to be_present
        expect(blog.title).to match(/\ATitle [0-9]+\z/)
        expect(blog.id).to be_present
        expect(Blog.where(:id => blog.id)).to exist
        expect(prefactory(:blog)).to eq(blog)
        expect(blog.counter).to eq(12)
      end
    end
    context "when using a different name and an explicit create call in a block" do
      before :all do
        prefactory_add(:some_other_blog) { create :blog, :counter => 24 }
      end
      it "uses the other name" do
        expect(some_other_blog).to be_present
        expect(some_other_blog.title).to match(/\ATitle [0-9]+\z/)
        expect(some_other_blog.id).to be_present
        expect(Blog.where(:id => some_other_blog.id)).to exist
        expect(prefactory(:some_other_blog)).to eq(some_other_blog)
        expect(some_other_blog.counter).to eq(24)
      end
    end
    context "when referencing the object within the before-all block" do
      before :all do
        prefactory_add :blog
        blog.update_attributes! :counter => 42
      end
      it "works" do
        expect(blog.counter).to eq(42)
      end
    end
    context "nesting a before-all with a prefactory_add" do
      before :all do
        prefactory_add :blog, :title => 'the big book of trains'
      end
      it { expect(blog).to be_present }
      context "and another before-all prefactory_add" do
        before :all do
          prefactory_add :comment, :blog => blog, :text => 'old text'
        end
        it do
          expect(comment).to be_present
          expect(comment.blog).to eq(blog)
        end
        it do
          expect(blog).to be_present
          expect(blog.title).to eq('the big book of trains')
        end
        context "when modifying the object in a before-each" do
          before do
            comment.update_attributes! :text => 'new text'
            blog.update_attributes! :title => 'the little book of calm'
          end
          it do
            expect(comment.text).to eq('new text')
          end
          it do
            expect(blog.title).to eq('the little book of calm')
          end
        end
        context "when modifying the object in a before-all" do
          before :all do
            comment.update_attributes! :text => 'new text'
            blog.update_attributes! :title => 'the little book of calm'
          end
          it do
            expect(comment.text).to eq('new text')
          end
          it do
            expect(blog.title).to eq('the little book of calm')
          end
        end
        context "when not modifying the object" do
          it do
            expect(comment.text).to eq('old text')
          end
          it do
            expect(blog.title).to eq('the big book of trains')
          end
        end
      end
      it "preserves the title" do
        expect(blog.title).to eq('the big book of trains')
      end
    end

    context "when called in a context which is not a before-all context" do
      before :all do
        prefactory_add :blog
      end
      before do
        @before_each_exception = nil
        begin
          prefactory_add(:another_blog)
        rescue => e
          @before_each_exception = e
        end
      end
      it "raises an error in a before-each context" do
        expect(@before_each_exception).to be_present
      end
      it "raises an error in an it-context" do
        expect { prefactory_add(:comment) }.to raise_error
      end
      it "works in a before-all context" do
        expect(prefactory(:blog)).to be_present
      end
    end
  end

  describe "#prefactory and its method_missing :key fallback" do
    before :all do
      prefactory_add :blog
    end
    subject { prefactory(key) }
    context "when passed a key associated with a prefactory_add'ed object" do
      let(:key) { :blog }
      it do
        is_expected.to be_present
        is_expected.to eq(blog)
        is_expected.to be_a Blog
      end
      context "that has since been destroyed in a before-each" do
        before { blog.destroy }
        it do
          is_expected.to be_present
          is_expected.to be_destroyed
          expect(blog).to be_present
          expect(Blog.where(:id => blog.id)).not_to exist
        end
      end
      context "that has since been destroyed in a before-all" do
        before(:all) { blog.destroy }
        it { is_expected.to be_nil }
        it "does not raise an error when calling the key name as a method" do
          expect(blog).to be_nil
        end
      end
    end
    context "when passed a nonexistent key" do
      let(:key) { :frog }
      it do
        is_expected.to be_nil
        expect { frog }.to raise_error(NameError)
      end
    end

    context "with multiple before(:all) blocks" do
      before(:all) { prefactory_add :blog }
      before(:all) { prefactory_add :comment }
      before(:all) { prefactory_add :another_blog, :title => blog.id.to_s }
      it do
        expect(blog).to be_present
        expect(Blog.where(:id => blog.id)).to exist
      end
      it do
        expect(comment).to be_present
        expect(Comment.where(:id => comment.id)).to exist
      end
      it do
        expect(another_blog.title).to eq(blog.id.to_s)
      end
    end
  end

  describe ".set!" do
    set!(:blog)
    set! :comment, :counter => 12
    set!(:some_other_comment) do
      FactoryGirl.create :comment, :text => blog.title
    end
    it do
      expect(blog).to be_present
      expect(Blog.where(:id => blog.id)).to exist
    end
    it do
      expect(comment).to be_present
      expect(comment.counter).to eq(12)
      expect(Comment.where(:id => comment.id)).to exist
    end
    it do
      expect(some_other_comment.text).to be_present
      expect(some_other_comment.text).to eq(blog.title)
    end
  end
end
