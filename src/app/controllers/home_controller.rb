require "miiCardConsumers"

class HomeController < ActionController::Base
	def index
		@view_model = HarnessViewModel.new()
		action = nil
		
		if request.post?
			@view_model.consumer_key = request.POST['oauth-consumer-key']
			@view_model.consumer_secret = request.POST['oauth-consumer-secret']
			@view_model.access_token = request.POST['oauth-access-token']
			@view_model.access_token_secret = request.POST['oauth-access-token-secret']
			
			@view_model.social_account_type = request.POST['social-account-type']
			@view_model.social_account_id = request.POST['social-account-id']
			
			@view_model.assurance_image_type = request.POST['assurance-image-type']
			
			action = request.POST['btn-invoke']
		end
		
		if !action.nil? && !@view_model.consumer_key.nil? && !@view_model.consumer_secret.nil? && !@view_model.access_token.nil? && !@view_model.access_token_secret.nil?	
			api = MiiCardOAuthClaimsService.new(@view_model.consumer_key, @view_model.consumer_secret, @view_model.access_token, @view_model.access_token_secret)
				  
			if action == "get-claims"
				@view_model.last_get_claims_result = prettify_response(api.get_claims(), self.method(:prettify_claims))
			elsif action == "is-user-assured"
				@view_model.last_is_user_assured_result = prettify_response(api.is_user_assured(), nil)
			elsif action == "is-social-account-assured" && !@view_model.social_account_type.nil? && !@view_model.social_account_id.nil?
				@view_model.last_is_social_account_assured_result = prettify_response(api.is_social_account_assured(@view_model.social_account_id, @view_model.social_account_type), nil)
			elsif action == "assurance-image" && !@view_model.assurance_image_type.nil?
				@view_model.show_assurance_image = true
			end
		elsif !action.nil?
			@view_model.show_oauth_details_required_error = true
		end
				
		respond_to do |format|
			format.html # index.html.erb
		end
	end
	
	def assuranceimage
		consumer_key = request.GET['oauth-consumer-key']
		consumer_secret = request.GET['oauth-consumer-secret']
		access_token = request.GET['oauth-access-token']
		access_token_secret = request.GET['oauth-access-token-secret']
		type = request.GET['type']
		
		if !consumer_key.nil? && !consumer_secret.nil? && !access_token.nil? && !access_token_secret.nil? && !type.nil?
			api = MiiCardOAuthClaimsService.new(consumer_key, consumer_secret, access_token, access_token_secret)			
			img = api.assurance_image(type)
			
			send_data(img, :type => "image/png", :disposition => 'inline')
		end
	end
	
	private
	def prettify_response(response, data_processor)
		toReturn = '<div class="response">'
		toReturn += render_fact('Status', response.status)
		toReturn += render_fact('Error code', response.error_code)
		toReturn += render_fact('Error message', response.error_message)
    
		if not data_processor
			toReturn += render_fact('Data', response.data)
		end
		
		toReturn += '</div>'
    
		if !data_processor.nil?
			toReturn += data_processor.call(response.data)
		end
		
		return toReturn
	end
	
	def prettify_claims(claims_obj)
		toReturn = '<div class="fact">'
		toReturn += "<h2>User profile</h2>"

		# Dump top-level properties
		toReturn += render_fact('Username', claims_obj.username)
		toReturn += render_fact('Salutation', claims_obj.salutation)
		toReturn += render_fact('First name', claims_obj.first_name)
		toReturn += render_fact('Middle name', claims_obj.middle_name)
		toReturn += render_fact('Last name', claims_obj.last_name)
		toReturn += render_fact('Identity verified?', claims_obj.identity_assured)
		toReturn += render_fact('Identity last verified', claims_obj.last_verified)
		toReturn += render_fact('Has a public profile?', claims_obj.has_public_profile)
		toReturn += render_fact('Previous first name', claims_obj.previous_first_name)
		toReturn += render_fact('Previous middle name', claims_obj.previous_middle_name)
		toReturn += render_fact('Previous last name', claims_obj.previous_last_name)
		toReturn += render_fact('Profile URL', claims_obj.profile_url)
		toReturn += render_fact('Profile short URL', claims_obj.profile_short_url)
		toReturn += render_fact('Card image URL', claims_obj.card_image_url)

		toReturn += render_fact_heading('Postal addresses')
		ct = 0
		for address in claims_obj.postal_addresses || []
			toReturn += "<div class='fact'><h4>[#{ct}]</h4>"
			toReturn += render_address(address)
			toReturn += '</div>'
			ct += 1
		end

		toReturn += render_fact_heading('Phone numbers')
		ct = 0
		for phone in claims_obj.phone_numbers || []
			toReturn += "<div class='fact'><h4>[#{ct}]</h4>"
			toReturn += render_phone_number(phone)
			toReturn += '</div>'
			ct += 1
		end

		toReturn += render_fact_heading('Email addresses') 
		ct = 0
		for email in claims_obj.email_addresses || []
			toReturn += "<div class='fact'><h4>[#{ct}]</h4>"
			toReturn += render_email(email)
			toReturn += '</div>'
			ct += 1
		end
		
		toReturn += render_fact_heading('Internet identities')
		ct = 0
		for identity in claims_obj.identities || []
			toReturn += "<div class='fact'><h4>[#{ct}]</h4>"
			toReturn += render_identity(identity)
			toReturn += '</div>'
			ct += 1
		end

		toReturn += render_fact_heading('Web properties')
		ct = 0
		for web in claims_obj.web_properties || []
			toReturn += "<div class='fact'><h4>[#{ct}]</h4>"
			toReturn += render_web_property(web)
			toReturn += '</div>'
			ct += 1
		end

		if claims_obj.public_profile
			toReturn += "<div class='fact'>"
			toReturn += prettify_claims(claims_obj.public_profile)
			toReturn += '</div>'
		end

		toReturn += '</div>'

		return toReturn
	end
   
	def render_fact_heading(heading)
		return "<h3>" + heading + "</h3>"
	end

	def render_fact(fact_name, fact_value)
		fact_value_render = fact_value.to_s || "[Empty]"
		return "<div class='fact-row'><span class='fact-name'>#{fact_name}</span><span class='fact-value'>#{fact_value_render}</span></div>"
	end

	def render_phone_number(phone_number)
		toReturn = '<div class="fact">'

		toReturn += render_fact('Display name', phone_number.display_name)
		toReturn += render_fact('Country code', phone_number.country_code)
		toReturn += render_fact('National number', phone_number.national_number)
		toReturn += render_fact('Is mobile?', phone_number.is_mobile)
		toReturn += render_fact('Is primary?', phone_number.is_primary)
		toReturn += render_fact('Verified?', phone_number.verified)

		toReturn += '</div>'

		return toReturn
	end
	
	def render_address(address)
		toReturn = '<div class="fact">'

		toReturn += render_fact('House', address.house)
		toReturn += render_fact('Line1', address.line1)
		toReturn += render_fact('Line2', address.line2)
		toReturn += render_fact('City', address.city)
		toReturn += render_fact('Region', address.region)
		toReturn += render_fact('Code', address.code)
		toReturn += render_fact('Country', address.country)
		toReturn += render_fact('Is primary?', address.is_primary)
		toReturn += render_fact('Verified?', address.verified)

		toReturn += '</div>'

		return toReturn
	end
	
	def render_email(email)
		toReturn = '<div class="fact">'

		toReturn += render_fact('Display name', email.display_name)
		toReturn += render_fact('Address', email.address)
		toReturn += render_fact('Is primary?', email.is_primary)
		toReturn += render_fact('Verified?', email.verified)

		toReturn += '</div>'

		return toReturn
	end
	
	def render_web_property(property)
		toReturn = '<div class="fact">'

		toReturn += render_fact('Display name', property.display_name)
		toReturn += render_fact('Identifier', property.identifier)
		toReturn += render_fact('Type', property.type)
		toReturn += render_fact('Verified?', property.verified)

		toReturn += '</div>'

		return toReturn
	end
	
	def render_identity(identity)
		toReturn = '<div class="fact">'

		toReturn += render_fact('Source', identity.source)
		toReturn += render_fact('User ID', identity.user_id)
		toReturn += render_fact('Profile URL', identity.profile_url)
		toReturn += render_fact('Verified?', identity.verified)

		toReturn += '</div>'

		return toReturn
	end
end

class HarnessViewModel
	attr_accessor :consumer_key, :consumer_secret, :access_token, :access_token_secret
	attr_accessor :oauth_details, :last_get_claims_result, :last_is_user_assured_result, :last_is_social_account_assured_result
	attr_accessor :show_assurance_image, :assurance_image_type, :social_account_id, :social_account_type, :show_oauth_details_required_error
end