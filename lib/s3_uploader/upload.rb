module S3Uploader

  # Read how to format S3 policy doc:
  # http://docs.aws.amazon.com/AmazonS3/latest/dev/HTTPPOSTForms.html

  ##
  # Adds methods to controllers
  #
  module Upload
    extend ActiveSupport::Concern

    ##
    # Creates a policy for client direct to S3 uploads
    #
    # == Parameters
    #
    # [key_starts_with (String)] - Directory in S3 directory you want file to end up in "/video/2012-10-11"
    # [private (Boolean)] - Whether upload is private
    # [conditions (Array)] - Additional conditions to set for acceptable uploads
    #
    # == Returns
    #
    # [string] - Base64 representation of policy
    #
    def s3_policy(key_starts_with: '', bucket: nil, acl: 'private', success_action_status: 201, conditions: [])
      bucket ||= S3Uploader.config.bucket

      raise 'S3 bucket not defined' unless bucket

      conditions += [
        {acl: acl},
        {success_action_status: success_action_status.to_s},
        {bucket: bucket}
      ]

      unless key_starts_with.blank?
        conditions += [["starts-with", "$key", key_starts_with]]
      end

      policy = {
        expiration: S3Uploader.config.expiration.from_now.utc.xmlschema,
        conditions: conditions
      }

      encoded_policy = Base64.encode64(policy.to_json).gsub(/\n/, '')
    end

    ##
    # HMAC digest generates a hash signature using SHA1 with your S3 access key used
    # to verify that any client requests are authorized.
    #
    # == Parameters
    #
    # [s3_policy (String)]
    #
    # == Returns
    #
    # [string] Base64 encoded digest
    #
    def s3_sign(s3_policy)
      Base64.encode64(OpenSSL::HMAC.digest(OpenSSL::Digest::Digest.new('sha1'), S3Uploader.config.access_key, s3_policy)).gsub(/\n/, '')
    end

    ##
    # Generates JSON for a S3 upload post request
    #
    # == Returns
    #
    # [{
    #   name: 'key',
    #   value: retdata.key
    # }, {
    #   name: 'AWSAccessKeyId',
    #   value: retdata.aws_id
    # }, {
    #   name: 'acl',
    #   value: 'private'
    # }, {
    #   name: 'policy',
    #   value: policy
    # }, {
    #   name: 'signature',
    #   value: signature
    # }, {
    #   name: 'success_action_status',
    #   value: 201
    # }, {
    #   name: 'Content-Type',
    #   value: data.files[0].type
    # }]
    def s3_json(conditions)
      self.s3_policy()

      return [
        {
          name: 'key',
          value: retdata.key
        }, {
          name: 'AWSAccessKeyId',
          value: self.aws_id
        }, {
          name: 'acl',
          value: 'private'
        }, {
          name: 'policy',
          value: policy
        }, {
          name: 'signature',
          value: signature
        }, {
          name: 'success_action_status',
          value: 201
        }
      ]
    end

    def aws_id
      S3Uploader.config.aws_id
    end
  end
end
