# encoding: utf-8
require File.dirname(__FILE__) + '/spec_helper'

describe "App" do
  include_context 'in site'

  context "access pages" do
    context '/' do
      subject { get '/'; last_response.body }
      it { should match('Test Site') }

      context 'when posts exists' do
        before do
          Factory(:xmas_post, :title => 'First Post')
          Factory(:newyear_post)
        end

        after { Post.destroy }

        it "entries should be sorted by created_at in descending" do
          subject.index(/First Post/).should be > subject.index(/Test Post \d+/)
        end
      end
    end

    context '/:id' do
      before do
        post = Factory(:post)
        get "/#{post.id}"
      end

      after { Post.destroy }
      subject { last_response.body }
      it { should match('Test Site') }
    end

    context '/tags/lokka/' do
      before { Factory(:tag, :name => 'lokka') }
      after { Tag.destroy }

      it "should show tag index" do
        get '/tags/lokka/'
        last_response.body.should match('Test Site')
      end
    end

    describe 'a draft post' do
      before do
        Factory(:draft_post_with_tag_and_category)
        @post =  Post.first(:draft => true)
        @post.should_not be_nil # gauntlet
        @post.tag_list.should_not be_empty
        @tag_name =  @post.tag_list.first
        @category_id =  @post.category.id
      end

      after do
        Post.destroy
        Category.destroy
      end

      it "the entry page should return 404" do
        get '/test-draft-post'
        last_response.status.should == 404
        get "/#{@post.id}"
        last_response.status.should == 404
      end

      it "index page should not show the post" do
        get '/'
        last_response.body.should_not match('Draft post')
      end

      it "tags page should not show the post" do
        get "/tags/#{@tag_name}/"
        last_response.body.should_not match('Draft post')
      end

      it "category page should not show the post" do
        get "/category/#{@category_id}/"
        last_response.body.should_not match('Draft post')
      end

      it "search result should not show the post" do
        get '/search/?query=post'
        last_response.body.should_not match('Draft post')
      end
    end

    context "with custom permalink" do
      before do
        @page = Factory(:page)
        Factory(:post_with_slug)
        Factory(:later_post_with_slug)
        Option.permalink_enabled = true
        Option.permalink_format = "/%year%/%monthnum%/%day%/%slug%"
      end

      after do
        Option.permalink_enabled = false
        Entry.destroy
      end

      it "an entry can be accessed by custom permalink" do
        get '/2011/01/09/welcome-lokka'
        last_response.body.should match('Welcome to Lokka!')
        last_response.body.should_not match('mediawiki test')
        get '/2011/01/10/a-day-later'
        last_response.body.should match('1 day passed')
        last_response.body.should_not match('Welcome to Lokka!')
      end

      it "should redirect to custom permalink when accessed with original permalink" do
        get '/welcome-lokka'
        last_response.should be_redirect
        follow_redirect!
        last_request.url.should match('/2011/01/09/welcome-lokka')

        Option.permalink_enabled = false
        get '/welcome-lokka'
        last_response.should_not be_redirect
      end

      it "should not redirect access to page" do
        get "/#{@page.id}"
        last_response.should_not be_redirect
      end

      it "should redirect to 0 filled url when accessed to non-0 prepended url in day/month" do
        get '/2011/1/9/welcome-lokka'
        last_response.should be_redirect
        follow_redirect!
        last_request.url.should match('/2011/01/09/welcome-lokka')
      end

      it "should remove trailing / of url by redirection" do
        get '/2011/01/09/welcome-lokka/'
        last_response.should be_redirect
        follow_redirect!
        last_request.url.should match('/2011/01/09/welcome-lokka')
      end

      it 'should return status code 200 if entry found by custom permalink' do
        get '/2011/01/09/welcome-lokka'
        last_response.status.should == 200
      end

      it 'should return status code 404 if entry not found' do
        get '/2011/01/09/welcome-wordpress'
        last_response.status.should == 404
      end
    end

    context "with continue reading" do
      before { Factory(:post_with_more) }
      after { Post.destroy }
      describe 'in entries index' do
        it "should hide texts after <!--more-->" do
          get '/'
          last_response.body.should match(/<p>a<\/p>\n\n<a href="\/[^"]*">Continue reading\.\.\.<\/a>\n*[ \t]+<\/div>/)
        end
      end

      describe 'in entry page' do
        it "should not hide after <!--more-->" do
          get '/post-with-more'
          last_response.body.should_not match(/<a href="\/9">Continue reading\.\.\.<\/a>\n*[ \t]+<\/div>/)
        end
      end
    end
  end

  context "access tag archive page" do
    before do
      Factory(:tag, :name => 'lokka')
      post = Factory(:post)
      post.tag_list = 'lokka'
      post.save
    end

    after { Post.destroy; Tag.destroy }

    it "should show lokka tag archive" do
      get '/tags/lokka/'
      last_response.should be_ok
      last_response.body.should match(/Test Post \d+/)
    end
  end
end
