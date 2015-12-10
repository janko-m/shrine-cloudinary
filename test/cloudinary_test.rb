require "test_helper"
require "shrine/storage/linter"

describe Shrine::Storage::Cloudinary do
  def cloudinary(options = {})
    Shrine::Storage::Cloudinary.new(options)
  end

  before do
    @cloudinary = cloudinary
    uploader_class = Class.new(Shrine)
    uploader_class.storages[:cloudinary] = @cloudinary
    @uploader = uploader_class.new(:cloudinary)
  end

  after do
    @cloudinary.clear!(:confirm)
  end

  it "passes the linter" do
    Shrine::Storage::Linter.new(cloudinary).call(->{image})
  end

  it "passes the linter with prefix" do
    Shrine::Storage::Linter.new(cloudinary(prefix: "prefix")).call(->{image})
  end

  it "passes the linter with resource type" do
    Shrine::Storage::Linter.new(cloudinary(resource_type: "raw")).call(->{image})
  end

  describe "#upload" do
    it "applies upload options" do
      @cloudinary.upload_options.update(width: 50, crop: :fit)
      @cloudinary.upload(image, "foo.jpg", metadata = {})

      assert_equal 50, metadata["width"]
    end

    it "applies additional options from metadata" do
      metadata = {"cloudinary" => {width: 50, crop: :fit}}
      @cloudinary.upload(image, "foo.jpg", metadata)

      assert_equal 50, metadata["width"]
    end

    it "can upload remote files" do
      uploaded_file = @uploader.upload(image, location: "foo.jpg")
      @cloudinary.upload(uploaded_file, "bar.jpg")

      assert @cloudinary.exists?("bar.jpg")
    end

    it "can upload other UploadedFiles" do
      uploaded_file = @uploader.upload(image, location: "foo.jpg")
      def @cloudinary.remote?(io) false end
      @cloudinary.upload(uploaded_file, "bar.jpg")

      assert @cloudinary.exists?("bar.jpg")
    end

    it "updates size and dimensions" do
      metadata = {"size" => 1, "width" => 1, "height" => 1}
      @cloudinary.upload(image, "foo.jpg", metadata)

      assert_equal Hash["size" => image.size, "width" => 100, "height" => 67], metadata
    end

    it "changes the extension to match the actual extension" do
      @cloudinary.upload(image, id = "foo.mp4")
      assert_equal "foo.jpg", id

      @cloudinary.upload(image, id = "foo")
      assert_equal "foo.jpg", id
    end

    it "doesn't try to modify id if it's frozen" do
      @cloudinary.upload(image, "foo.mp4".freeze)
    end

    it "uploads large files" do
      @cloudinary = cloudinary(large: 1)
      @cloudinary.upload(image, "foo.jpg")

      assert @cloudinary.exists?("foo.jpg")
    end
  end

  describe "#url" do
    it "returns the URL with an extension" do
      assert_includes @cloudinary.url("foo.jpg"), "foo.jpg"
    end

    it "accepts additional options" do
      url = @cloudinary.url("foo.jpg", crop: :fit, width: 150, height: 150)

      assert_includes url, "c_fit"
      assert_includes url, "h_150"
      assert_includes url, "w_150"
    end

    it "respects resource type" do
      cloudinary = cloudinary(resource_type: "video")

      assert_includes cloudinary.url("foo.mp4"), "video"
    end
  end
end
