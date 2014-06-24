
module SSL
  class BaseRewriter
    def modify_request(request)
      request
    end

    def modify_response(response)
      response
    end
  end
end
