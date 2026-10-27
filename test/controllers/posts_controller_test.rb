require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  test "root renders an empty list" do
    Post.delete_all
    get root_url
    assert_response :success
    assert_select "a[href=?]", new_post_path
    assert_select "div[id^=post_]", count: 0
  end

  test "new and edit forms have title and body fields" do
    get new_post_url
    assert_response :success
    assert_select "input[name=?]", "post[title]"
    assert_select "textarea[name=?]", "post[body]"

    get edit_post_url(posts(:one))
    assert_response :success
    assert_select "input[name=?]", "post[title]"
    assert_select "textarea[name=?]", "post[body]"
  end

  test "create read update and delete a post" do
    title = "Dockerブログ <記事>"
    body = "日本語の本文です。\n2行目も保存します。"

    assert_difference("Post.count", 1) do
      post posts_url, params: { post: { title: title, body: body } }
    end
    created = Post.order(:id).last
    assert_equal title, created.title
    assert_equal body, created.body
    assert_redirected_to post_url(created)
    follow_redirect!
    assert_response :success
    assert_includes response.body, ERB::Util.html_escape(title)
    assert_includes response.body, body

    get posts_url
    assert_response :success
    assert_select "#post_#{created.id}", text: /Dockerブログ/

    patch post_url(created), params: { post: { title: "更新したタイトル", body: "更新した本文" } }
    assert_redirected_to post_url(created)
    assert_equal "更新したタイトル", created.reload.title
    assert_equal "更新した本文", created.body
    follow_redirect!
    assert_includes response.body, "更新した本文"

    assert_difference("Post.count", -1) { delete post_url(created) }
    assert_redirected_to posts_url
    assert_not Post.exists?(created.id)
    get post_url(created)
    assert_response :not_found
  end

  test "posts with the same title remain independent" do
    assert_difference("Post.count", 2) do
      post posts_url, params: { post: { title: "同じタイトル", body: "1件目" } }
      post posts_url, params: { post: { title: "同じタイトル", body: "2件目" } }
    end
    first, second = Post.where(title: "同じタイトル").order(:id).to_a
    assert_not_equal first.id, second.id
    patch post_url(first), params: { post: { title: "更新後", body: "更新後の本文" } }
    assert_redirected_to post_url(first)
    assert_equal "同じタイトル", second.reload.title
    assert_equal "2件目", second.body
  end

  test "blank title or body does not create a post" do
    [ { title: " ", body: "本文" }, { title: "題名", body: " " }, { title: "", body: "" } ].each do |attributes|
      assert_no_difference("Post.count") { post posts_url, params: { post: attributes } }
      assert_response :unprocessable_content
      assert_select "li", text: /can't be blank/
    end
  end

  test "invalid update preserves the saved title and body" do
    record = posts(:one)
    original = record.attributes.slice("title", "body")
    patch post_url(record), params: { post: { title: "", body: "changed" } }
    assert_response :unprocessable_content
    assert_equal original, record.reload.attributes.slice("title", "body")
  end

  test "health check responds successfully" do
    get rails_health_check_url
    assert_response :success
  end
end
