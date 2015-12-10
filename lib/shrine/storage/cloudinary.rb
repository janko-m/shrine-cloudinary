require "cloudinary"
require "down"

class Shrine
  module Storage
    class Cloudinary
      attr_reader :prefix, :resource_type, :upload_options

      def initialize(prefix: nil, large: nil, resource_type: "image", upload_options: {})
        @prefix = prefix
        @large = large
        @resource_type = resource_type
        @upload_options = upload_options.merge(resource_type: resource_type)
      end

      def upload(io, id, metadata = {})
        options = {public_id: public_id(id)}
        options.update(upload_options)
        options.update(metadata.delete("cloudinary") || {})

        chunk_size = options.delete(:chunk_size)

        result =
          if remote?(io)
            uploader.upload(io.storage.url(io.id), **options)
          else
            io = io.download if io.is_a?(UploadedFile)
            if large?(io)
              uploader.upload_large(io, chunk_size: chunk_size, **options)
            else
              uploader.upload(io, **options)
            end
          end

        update_id!(result, id)
        update_metadata!(result, metadata)
      end

      def download(id)
        Down.download(url(id))
      end

      def move(io, id, metadata = {})
        uploader.rename(io.storage.public_id(io.id), public_id(id), resource_type: resource_type)
      end

      def movable?(io, id)
        io.is_a?(UploadedFile) && io.storage.is_a?(Storage::Cloudinary)
      end

      def open(id)
        download(id)
      end

      def read(id)
        downloader.download(url(id))
      end

      def exists?(id)
        result = api.resources_by_ids([public_id(id)], resource_type: resource_type)
        result.fetch("resources").any?
      end

      def delete(id)
        uploader.destroy(public_id(id), resource_type: resource_type)
      end

      def multi_delete(ids)
        public_ids = ids.map { |id| public_id(id) }
        api.delete_resources(public_ids, resource_type: resource_type)
      end

      def url(id, **options)
        utils.cloudinary_url(path(id), resource_type: resource_type, type: type, **options)
      end

      def clear!(confirm = nil, **options)
        raise Shrine::Confirm unless confirm == :confirm
        if prefix
          api.delete_resources_by_prefix(prefix, resource_type: resource_type, **options)
        else
          api.delete_all_resources(resource_type: resource_type, **options)
        end
      end

      protected

      def public_id(id)
        if resource_type == "raw"
          path(id)
        else
          path(id).chomp(File.extname(id))
        end
      end

      def path(id)
        [*prefix, id].join("/")
      end

      private

      def type
        upload_options[:type] || "upload"
      end

      def remote?(io)
        io.is_a?(UploadedFile) && io.storage.url(io.id) =~ /^ftp:|^https?:/
      end

      def large?(io)
        io.size >= @large if @large
      end

      def update_id!(result, id)
        unless resource_type == "raw" || id.frozen?
          id.gsub!(/#{File.extname(id)}$/, ".#{result.fetch("format")}")
        end
      end

      def update_metadata!(result, metadata)
        size, width, height = result.values_at("bytes", "width", "height")
        metadata.update("size" => size)
        metadata.update("width" => width, "height" => height) if resource_type == "image"
      end

      [:Uploader, :Downloader, :Utils, :Api].each do |name|
        define_method(name.downcase) { ::Cloudinary.const_get(name) }
      end
    end
  end
end
