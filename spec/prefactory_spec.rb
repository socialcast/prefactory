require 'spec_helper'

describe "FactoryGirl integration" do
  describe "prefactory_add" do

    context "when passing a block with no FactoryGirl activity" do
      before :all do
        prefactory_add(:my_blog) do
          Blog.create! :title => 'My Blog'
        end
      end
      it "creates an object using the provided name" do
        my_blog.should be_present
        my_blog.title.should == 'My Blog'
        my_blog.id.should be_present
        Blog.where(:id => my_blog.id).should exist
        prefactory(:my_blog).should == my_blog
        my_blog.counter.should be_nil
      end
    end

    context "when passing just a FactoryGirl factory name" do
      before :all do
        prefactory_add :blog
      end
      it "creates an object based on the factory name, via FactoryGirl::Syntax::Methods" do
        blog.should be_present
        blog.title.should =~ /\ATitle [0-9]+\z/
        blog.id.should be_present
        Blog.where(:id => blog.id).should exist
        prefactory(:blog).should == blog
        blog.counter.should be_nil
      end
    end
    context "when passing a factory name and additional attributes" do
      before :all do
        prefactory_add :blog, :counter => 12
      end
      it "uses the additional attributes" do
        blog.should be_present
        blog.title.should =~ /\ATitle [0-9]+\z/
        blog.id.should be_present
        Blog.where(:id => blog.id).should exist
        prefactory(:blog).should == blog
        blog.counter.should == 12
      end
    end
    context "when using a different name and an explicit create call in a block" do
      before :all do
        prefactory_add(:some_other_blog) { create :blog, :counter => 24 }
      end
      it "uses the other name" do
        some_other_blog.should be_present
        some_other_blog.title.should =~ /\ATitle [0-9]+\z/
        some_other_blog.id.should be_present
        Blog.where(:id => some_other_blog.id).should exist
        prefactory(:some_other_blog).should == some_other_blog
        some_other_blog.counter.should == 24
      end
    end
    context "when referencing the object within the before-all block" do
      before :all do
        prefactory_add :blog
        blog.update_attributes! :counter => 42
      end
      it "works" do
        blog.counter.should == 42
      end
    end
    context "nesting a before-all with a prefactory_add" do
      before :all do
        prefactory_add :blog, :title => 'the big book of trains'
      end
      it { blog.should be_present }
      context "and another before-all prefactory_add" do
        before :all do
          prefactory_add :comment, :blog => blog, :text => 'old text'
        end
        it do
          comment.should be_present
          comment.blog.should == blog
        end
        it do
          blog.should be_present
          blog.title.should == 'the big book of trains'
        end
        context "when modifying the object in a before-each" do
          before do
            comment.update_attributes! :text => 'new text'
            blog.update_attributes! :title => 'the little book of calm'
          end
          it do
            comment.text.should == 'new text'
          end
          it do
            blog.title.should == 'the little book of calm'
          end
        end
        context "when modifying the object in a before-all" do
          before :all do
            comment.update_attributes! :text => 'new text'
            blog.update_attributes! :title => 'the little book of calm'
          end
          it do
            comment.text.should == 'new text'
          end
          it do
            blog.title.should == 'the little book of calm'
          end
        end
        context "when not modifying the object" do
          it do
            comment.text.should == 'old text'
          end
          it do
            blog.title.should == 'the big book of trains'
          end
        end
      end
      it "preserves the title" do
        blog.title.should == 'the big book of trains'
      end
    end
  end
end
