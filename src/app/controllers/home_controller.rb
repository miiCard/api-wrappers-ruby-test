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

			@view_model.snapshot_id = request.POST['snapshot-id']
			@view_model.snapshot_details_id = request.POST['snapshot-details-id']
			@view_model.snapshot_pdf_id = request.POST['snapshot-pdf-id']

			@view_model.assurance_image_type = request.POST['assurance-image-type']
			
			@view_model.card_image_format = request.POST['card-image-format']
			@view_model.card_image_snapshot_id = request.POST['card-image-snapshot-id']
			@view_model.card_image_show_email_address = request.POST['card-image-show-email-address'] == "on"
			@view_model.card_image_show_phone_number = request.POST['card-image-show-phone-number'] == "on"

			@view_model.authentication_details_snapshot_id = request.POST['authentication-details-snapshot-id']

			@view_model.financial_data_modesty_limit = (request.POST['financial_data_modesty_limit'].to_s.empty?) ? nil : request.POST['financial_data_modesty_limit'].to_f
			@view_model.financial_data_modesty_limit_raw = request.POST['financial_data_modesty_limit']
			@view_model.financial_data_credit_cards_modesty_limit = (request.POST['financial_data_credit_cards_modesty_limit'].to_s.empty?) ? nil : request.POST['financial_data_credit_cards_modesty_limit'].to_f
			@view_model.financial_data_credit_cards_modesty_limit_raw = request.POST['financial_data_credit_cards_modesty_limit']

			@view_model.directory_criterion = request.POST['directory_criterion']
			@view_model.directory_criterion_value = request.POST['directory_criterion_value']

			@view_model.directory_criterion_value_hashed = request.POST['directory_criterion_value_hashed'] == "on"
			
			action = request.POST['btn-invoke']
		end

		if !action.to_s.empty? && action == "directory-search"
			directory_result = MiiCardDirectoryService.new().find_by(@view_model.directory_criterion, @view_model.directory_criterion_value, @view_model.directory_criterion_value_hashed)
			if !directory_result.nil?
				@view_model.last_directory_search_result = prettify_claims(directory_result)
			end
		elsif !action.to_s.empty? && !@view_model.consumer_key.to_s.empty? && !@view_model.consumer_secret.to_s.empty? && !@view_model.access_token.to_s.empty? && !@view_model.access_token_secret.to_s.empty?	
			api = MiiCardOAuthClaimsService.new(@view_model.consumer_key, @view_model.consumer_secret, @view_model.access_token, @view_model.access_token_secret)
			financial_api = MiiCardOAuthFinancialService.new(@view_model.consumer_key, @view_model.consumer_secret, @view_model.access_token, @view_model.access_token_secret)
				  
			if action == "get-claims"
				@view_model.last_get_claims_result = prettify_response(api.get_claims(), self.method(:prettify_claims))
			elsif action == "is-user-assured"
				@view_model.last_is_user_assured_result = prettify_response(api.is_user_assured(), nil)
			elsif action == "is-social-account-assured" && !@view_model.social_account_type.to_s.empty? && !@view_model.social_account_id.to_s.empty?
				@view_model.last_is_social_account_assured_result = prettify_response(api.is_social_account_assured(@view_model.social_account_id, @view_model.social_account_type), nil)
			elsif action == "assurance-image" && !@view_model.assurance_image_type.to_s.empty?
				@view_model.show_assurance_image = true
			elsif action == "card-image"
				@view_model.show_card_image = true
			elsif action == "create-identity-snapshot"
				@view_model.last_create_identity_snapshot_result = prettify_response(api.create_identity_snapshot(), self.method(:prettify_identity_snapshot_details))
			elsif action == "get-identity-snapshot-details"
				@view_model.last_get_identity_snapshot_details_result = prettify_response(api.get_identity_snapshot_details(@view_model.snapshot_details_id), self.method(:prettify_identity_snapshot_details))
			elsif action == "get-identity-snapshot" && !@view_model.snapshot_id.to_s.empty?
				@view_model.last_get_identity_snapshot_result = prettify_response(api.get_identity_snapshot(@view_model.snapshot_id), self.method(:prettify_identity_snapshot))
			elsif action == "get-identity-snapshot-pdf" && !@view_model.snapshot_pdf_id.to_s.empty?
				send_data(api.get_identity_snapshot_pdf(@view_model.snapshot_pdf_id), :type => "application/pdf", :disposition => 'attachment; filename="' + @view_model.snapshot_pdf_id + '"')
				return
			elsif action == "get-authentication-details"
				@view_model.last_get_authentication_details_result = prettify_response(api.get_authentication_details(@view_model.authentication_details_snapshot_id), self.method(:prettify_authentication_details))
			elsif action == "is-credit-bureau-refresh-in-progress"
				@view_model.is_credit_bureau_refresh_in_progress_result = prettify_response(api.is_credit_bureau_refresh_in_progress(), nil)
			elsif action == "refresh-credit-bureau-data"
				@view_model.refresh_credit_bureau_data_result = prettify_response(api.refresh_credit_bureau_data(), self.method(:prettify_credit_bureau_refresh_status))
			elsif action == "is-refresh-in-progress"
				@view_model.last_is_refresh_in_progress_result = prettify_response(financial_api.is_refresh_in_progress(), nil)
			elsif action == "is-refresh-in-progress-credit-cards"
				@view_model.last_is_refresh_in_progress_credit_cards_result = prettify_response(financial_api.is_refresh_in_progress_credit_cards(), nil)
			elsif action == "refresh-financial-data"
				@view_model.last_refresh_financial_data_result = prettify_response(financial_api.refresh_financial_data(), self.method(:prettify_financial_refresh_status))
			elsif action == "refresh-financial-data-credit-cards"
				@view_model.last_refresh_financial_data_credit_cards_result = prettify_response(financial_api.refresh_financial_data_credit_cards(), self.method(:prettify_financial_refresh_status))
			elsif action == "get-financial-transactions"
				configuration = PrettifyConfiguration.new(@view_model.financial_data_modesty_limit)
				@view_model.last_get_financial_transactions_result = prettify_response(financial_api.get_financial_transactions(), self.method(:prettify_financial_data), configuration)
			elsif action == "get-financial-transactions-credit-cards"
				configuration = PrettifyConfiguration.new(@view_model.financial_data_credit_cards_modesty_limit)
				@view_model.last_get_financial_transactions_credit_cards_result = prettify_response(financial_api.get_financial_transactions_credit_cards(), self.method(:prettify_financial_data), configuration)
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
			
			send_data(img, :type => 'image/png', :disposition => 'inline')
		end
	end

	def cardimage
		consumer_key = request.GET['oauth-consumer-key']
		consumer_secret = request.GET['oauth-consumer-secret']
		access_token = request.GET['oauth-access-token']
		access_token_secret = request.GET['oauth-access-token-secret']

		format = request.GET['format']
		snapshot_id = request.GET['snapshot-id']
		show_email_address = request.GET['show-email-address']
		show_phone_number = request.GET['show-phone-number']

		if !consumer_key.nil? && !consumer_secret.nil? && !access_token.nil? && !access_token_secret.nil? 
			api = MiiCardOAuthClaimsService.new(consumer_key, consumer_secret, access_token, access_token_secret)
			img = api.get_card_image(snapshot_id, show_email_address == 'true', show_phone_number == 'true', format)

			send_data(img, :type => 'image/png', :disposition => 'inline')
		end
	end

	def sha1
		render :text => MiiCardDirectoryService.hash_identifier(request.GET['identifier'])
	end
	
	private
	def prettify_response(response, data_processor, configuration = nil)
		toReturn = '<div class="response">'
		toReturn += render_fact('Status', response.status)
		toReturn += render_fact('Error code', response.error_code)
		toReturn += render_fact('Error message', response.error_message)
		toReturn += render_fact('Is test user?', response.is_test_user)
    
		if not data_processor
			toReturn += render_fact('Data', response.data)
		end
		
		toReturn += '</div>'
    
		if !data_processor.nil?
			if response.data.kind_of?(Array)
				ct = 0
				for index in 0 ... response.data.size
					toReturn += "<div class='fact'><h4>[" + ct.to_s + "]</h4>"
					toReturn += data_processor.call(response.data[index], configuration)
					toReturn += "</div>"

					ct += 1
				end
			else
				toReturn += data_processor.call(response.data, configuration)
			end
		end
		
		return toReturn
	end

	def prettify_identity_snapshot(identity_snapshot, configuration = nil)
		toReturn = "<div class='fact'>"

		toReturn += render_fact_heading("Snapshot details")
		toReturn += prettify_identity_snapshot_details(identity_snapshot.details)

		toReturn += render_fact_heading("Snapshot contents")
		toReturn += prettify_claims(identity_snapshot.snapshot)

		toReturn += "</div>"

		return toReturn
	end

	def prettify_identity_snapshot_details(snapshot_details, configuration = nil)
	    toReturn = "<div class='fact'>"

		toReturn += render_fact("Snapshot ID", snapshot_details.snapshot_id)
		toReturn += render_fact("Username", snapshot_details.username)
		toReturn += render_fact("Timestamp",  snapshot_details.timestamp_utc)
		toReturn += render_fact("Was a test user?", snapshot_details.was_test_user)
		toReturn += "</div>"

		return toReturn
	end
	
	def prettify_claims(claims_obj, configuration = nil)
		toReturn = '<div class="fact">'
		toReturn += "<h2>User profile</h2>"

		# Dump top-level properties
		toReturn += render_fact('Username', claims_obj.username)
		toReturn += render_fact('Salutation', claims_obj.salutation)
		toReturn += render_fact('First name', claims_obj.first_name)
		toReturn += render_fact('Middle name', claims_obj.middle_name)
		toReturn += render_fact('Last name', claims_obj.last_name)
		toReturn += render_fact('Date of birth', claims_obj.date_of_birth)
		toReturn += render_fact('Age', claims_obj.age)
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

		toReturn += render_fact_heading('Qualifications')
		ct = 0
		for qualification in claims_obj.qualifications || []
			toReturn += "<div class='fact'><h4>[#{ct}]</h4>"
			toReturn += render_qualification(qualification)
			toReturn += '</div>'
			ct += 1
		end

		toReturn += render_fact_heading('Credit bureau data')
		if claims_obj.credit_bureau_verification
			toReturn += render_credit_bureau_verification(claims_obj.credit_bureau_verification)
		end

		if claims_obj.public_profile
			toReturn += "<div class='fact'>"
			toReturn += prettify_claims(claims_obj.public_profile)
			toReturn += '</div>'
		end

		toReturn += '</div>'

		return toReturn
	end

	def prettify_authentication_details(authentication_details, configuration = nil)
	    to_return = "<div class='fact'>"
        to_return += render_fact_heading("Authentication details")

        to_return += render_fact("Timestamp UTC", authentication_details.authentication_time_utc)
        to_return += render_fact("2FA type", authentication_details.second_factor_token_type)
        to_return += render_fact("2FA provider", authentication_details.second_factor_provider)

        to_return += "<div class='fact'>"
        to_return += render_fact_heading("Locations")
				
		ct = 0
		for location in authentication_details.locations || []
			to_return += "<div class='fact'><h4>[#{ct}]</h4>"
			to_return += render_geographic_location(location)
			to_return += '</div>'
			ct += 1
		end

        to_return += "</div></div>"

        return to_return;
	end

	def prettify_financial_data(financial_data, configuration)
        to_return = "<div class='fact'>"

        to_return += "<h2>Financial Data</h2>"
        to_return += render_fact_heading("Financial Providers")

        ct = 0
        for provider in financial_data.financial_providers || []
            to_return += "<div class='fact'><h4>[#{ct}]</h4>"
            to_return += render_financial_provider(provider, configuration)
            to_return += "</div>"

			ct += 1
		end

        to_return += "</div>"

        return to_return;
	end

	def prettify_credit_bureau_refresh_status(credit_bureau_refresh_status, configuration)
        to_return = "<div class='fact'>"

        to_return += render_fact('State', credit_bureau_refresh_status.state)

        to_return += "</div>"

        return to_return;
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

	def render_qualification(qualification)
		toReturn = '<div class="fact">'

		toReturn += render_fact('Type', qualification.type)
		toReturn += render_fact('Title', qualification.title)
		toReturn += render_fact('Data Provider', qualification.data_provider)
		toReturn += render_fact('Data Provider URL', qualification.data_provider_url)

		toReturn += '</div>'

		return toReturn
	end
	
	def render_geographic_location(location)
	    to_return = "<div class='fact'>";

        to_return += render_fact("Provider", location.location_provider)
        to_return += render_fact("Latitude", location.latitude)
        to_return += render_fact("Longitude", location.longitude)
        to_return += render_fact("Accuracy (metres, est.)", location.lat_long_accuracy_metres)

        if (!location.approximate_address.nil?)
            to_return += render_fact_heading("Approximate postal address")

            to_return += render_address(location.approximate_address)
        else
            to_return += render_fact("Approximate postal address", nil)
		end

        to_return += "</div>"
        return to_return;
	end

	def render_credit_bureau_verification(verification)
		to_return = "<div class='fact'>";

        to_return += render_fact("Last verified", verification.last_verified)
        to_return += render_fact("Data", verification.data)

        to_return += "</div>"
        return to_return;
	end

    def render_financial_account(account, configuration)
        to_return = "<div class='fact'>"

        to_return += render_fact("Holder", account.holder)
        to_return += render_fact("Account number", account.account_number)
        to_return += render_fact("Sort code", account.sort_code)
        to_return += render_fact("Account name", account.account_name)
        to_return += render_fact("Type", account.type)
        to_return += render_fact("Last updated", account.last_updated_utc)
        to_return += render_fact("Currency", account.currency_iso)
        to_return += render_fact("Closing balance", get_modesty_filtered_amount(account.closing_balance, configuration))
        to_return += render_fact("Credits (count)", account.credits_count)
        to_return += render_fact("Credits (sum)", get_modesty_filtered_amount(account.credits_sum, configuration))
        to_return += render_fact("Debits (count)", account.debits_count)
        to_return += render_fact("Debits (sum)", get_modesty_filtered_amount(account.debits_sum, configuration))

        to_return += render_fact_heading("Transactions");

        to_return += "<table class='table table-striped table-condensed table-hover'><thead><tr><th>Date</th><th>Description</th><th class='r'>Credit</th><th class='r'>Debit</th></tr></thead><tbody>"

		for transaction in account.transactions || []
			to_return += "<tr><td>%s</td><td title='ID: %s'>%s</td><td class='r'>%s</td><td class='r d'>%s</td></tr>" % [ render_as_date(transaction.date), transaction.id, render_possibly_null(transaction.description, '[None]'), get_modesty_filtered_amount(transaction.amount_credited, configuration), get_modesty_filtered_amount(transaction.amount_debited, configuration)]
		end

        to_return += "</tbody></table>"

        to_return += "</div>"
        return to_return
    end

    def render_financial_credit_card(credit_card, configuration)
        to_return = "<div class='fact'>"

        to_return += render_fact("Holder", credit_card.holder)
        to_return += render_fact("Account number", credit_card.account_number)
        to_return += render_fact("Account name", credit_card.account_name)
        to_return += render_fact("Type", credit_card.type)
        to_return += render_fact("Last updated", credit_card.last_updated_utc)
        to_return += render_fact("Currency", credit_card.currency_iso)
        to_return += render_fact("Credit limit", get_modesty_filtered_amount(credit_card.credit_limit, configuration))
        to_return += render_fact("Running balance", get_modesty_filtered_amount(credit_card.running_balance, configuration))
        to_return += render_fact("Credits (count)", credit_card.credits_count)
        to_return += render_fact("Credits (sum)", get_modesty_filtered_amount(credit_card.credits_sum, configuration))
        to_return += render_fact("Debits (count)", credit_card.debits_count)
        to_return += render_fact("Debits (sum)", get_modesty_filtered_amount(credit_card.debits_sum, configuration))

        to_return += render_fact_heading("Transactions");

        to_return += "<table class='table table-striped table-condensed table-hover'><thead><tr><th>Date</th><th>Description</th><th class='r'>Credit</th><th class='r'>Debit</th></tr></thead><tbody>"

		for transaction in credit_card.transactions || []
			to_return += "<tr><td>%s</td><td title='ID: %s'>%s</td><td class='r'>%s</td><td class='r d'>%s</td></tr>" % [ render_as_date(transaction.date), transaction.id, render_possibly_null(transaction.description, '[None]'), get_modesty_filtered_amount(transaction.amount_credited, configuration), get_modesty_filtered_amount(transaction.amount_debited, configuration)]
		end

        to_return += "</tbody></table>"

        to_return += "</div>"
        return to_return
    end

	def render_financial_provider(financial_provider, configuration)
		to_return = "<div class='fact'>"

        to_return += render_fact("Name", financial_provider.provider_name)

        ct = 0
		if (!financial_provider.financial_accounts.nil? && !financial_provider.financial_accounts.empty?)
			to_return += render_fact_heading("Financial Accounts")

			for account in financial_provider.financial_accounts
				to_return += "<div class='fact'><h4>[#{ct}]</h4>"
				to_return += render_financial_account(account, configuration)
				to_return += "</div>"

				ct += 1
			end
		elsif (!financial_provider.financial_credit_cards.nil? && !financial_provider.financial_credit_cards.empty?)
			to_return += render_fact_heading("Financial Credit Cards")

			for credit_card in financial_provider.financial_credit_cards
				to_return += "<div class='fact'><h4>[#{ct}]</h4>"
				to_return += render_financial_credit_card(credit_card, configuration)
				to_return += "</div>"

				ct += 1
			end
		end

        to_return += "</div>"

        return to_return;
	end

	def render_possibly_null(value, default)
		if value.to_s.empty?
			return default
		else
			return value
		end
	end

	def render_as_date(date)
		if date.nil?
			return nil
		else
			return date.strftime('%Y-%m-%d')
		end
	end
	
	def get_modesty_filtered_amount(amount, configuration)
		to_return = ''

		if !amount.nil?
			limit = nil
			if !configuration.nil? && !configuration.modesty_limit.nil?
				limit = configuration.modesty_limit
			end

			if limit.nil? || amount.abs <= limit
				to_return = "%.2f" % amount
			else
				to_return = '?.??'
			end
		end

		return to_return
	end
end

class HarnessViewModel
	attr_accessor :consumer_key, :consumer_secret, :access_token, :access_token_secret
	attr_accessor :oauth_details, :last_get_claims_result, :last_is_user_assured_result, :last_is_social_account_assured_result
	attr_accessor :snapshot_id, :snapshot_details_id, :last_get_identity_snapshot_details_result, :last_create_identity_snapshot_result, :last_get_identity_snapshot_result
	attr_accessor :show_assurance_image, :assurance_image_type, :social_account_id, :social_account_type, :show_oauth_details_required_error
	attr_accessor :snapshot_pdf_id
	attr_accessor :card_image_snapshot_id, :card_image_format, :card_image_show_email_address, :card_image_show_phone_number, :show_card_image
	attr_accessor :authentication_details_snapshot_id, :last_get_authentication_details_result
	attr_accessor :is_credit_bureau_refresh_in_progress_result, :refresh_credit_bureau_data_result
	attr_accessor :last_is_refresh_in_progress_result, :last_refresh_financial_data_result, :last_get_financial_transactions_result
	attr_accessor :last_is_refresh_in_progress_credit_cards_result, :last_refresh_financial_data_credit_cards_result, :last_get_financial_transactions_credit_cards_result
	attr_accessor :financial_data_modesty_limit, :financial_data_modesty_limit_raw, :financial_data_credit_cards_modesty_limit, :financial_data_credit_cards_modesty_limit_raw

	attr_accessor :directory_criterion, :directory_criterion_value, :directory_criterion_value_hashed
	attr_accessor :last_directory_search_result
end

class PrettifyConfiguration
	attr_accessor :modesty_limit

	def initialize(modesty_limit)
		@modesty_limit = modesty_limit
	end
end