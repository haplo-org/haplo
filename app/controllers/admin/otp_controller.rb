# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class Admin_OtpController < ApplicationController
  policies_required :not_anonymous, :control_trust

  def handle_index
    @users = User.where(:kind => User::KIND_USER).order(:name)
    @user_with_temporary_code = KHardwareOTP.get_temporary_code_user_id
  end

  _GetAndPost
  def handle_set
    return unless load_user
    @new_assignment = (nil == @user.otp_identifier)
    if request.post?
      @set_attempted = true
      @identifier = params[:identifier].gsub(/\s/,'') # remove whitespace
      otp = params[:password].gsub(/\D/,'') # remove all non-digit letters
      if otp.length > 5
        @otp_result = KHardwareOTP.check_otp(@identifier, otp, request.remote_ip)
        if @otp_result.ok
          # OTP was correct, set token for user
          @user.otp_identifier = @identifier
          @user.save!
          redirect_to '/do/admin/otp'
        end
      end
    end
  end

  _GetAndPost
  def handle_withdraw
    return unless load_user
    @user_requires_token = @user.policy.is_otp_token_required?
    if request.post?
      @user.otp_identifier = nil
      @user.save!
      redirect_to '/do/admin/otp'
    end
  end

  def handle_temp_code
    unless nil != @request_user.otp_identifier
      render :action => 'temp_code_no_otp'
      return
    end
    @users = User.where(:kind => User::KIND_USER).where('otp_identifier IS NOT NULL').order(:name)
  end

  def handle_temp_code2
    return unless load_user
  end

  _GetAndPost
  def handle_temp_code3
    return unless load_user
    if request.post?
      otp = params[:password].gsub(/\D/,'')
      if otp.length > 5
        @otp_result = KHardwareOTP.check_otp(@request_user.otp_identifier, otp, request.remote_ip)
        if @otp_result.ok
          @temporary_code = KRandom.random_hex(50).gsub(/\D/,'')[0,8]
          KHardwareOTP.set_temporary_code(@user.id, @temporary_code)
          render :action => 'temp_code4'
        end
      end
    end
  end

  def handle_temp_code_bad
  end

  def handle_remove_temp_code
    KHardwareOTP.clear_temporary_code
    redirect_to '/do/admin/otp'
  end

private

  def load_user
    @user = User.find(params[:id])
    unless @user != nil && @user.kind == User::KIND_USER
      redirect_to '/do/admin/otp'
      false
    else
      true
    end
  end

end

