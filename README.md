# STUNT BANANA
#### Minimalist Asterisk Caller ID Spoofer and Secondary VOIP Line Configuration Built for AWS

Contact: DilDog ([twitter.com/dildog](https://twitter.com/dildog)) (dildog@l0pht.com)

---

## Introduction

Things to know:
1. **STUNT BANANA** provides a Caller ID spoofing mechanism much like **SpoofCard** and other available services, but at a much reduced cost, if you don't mind doing the setup yourself and having a much more minimal UI.
2. **STUNT BANANA** also allows you to host new phone numbers (DIDs) for your devices and use a SIP Phone app, such as [Zoiper](https://www.zoiper.com/) to place and receive calls, as well as get voicemail for those lines sent your email as MP3 files. 
3. Spoofing Caller ID is not illegal. Impersonating other people and committing fraud is. If you bulk call people with spoofed caller IDs, your SIP trunk provider will notice and you will get taken down and possibly receive criminal charges. Don't be dumb.
 
## Acknowledgements

Props to [Jonathan Stines](https://twitter.com/fr4nk3nst1ner) for his blog entries about this subject:

* https://blog.rapid7.com/2018/05/24/how-to-build-your-own-caller-id-spoofer-part-1/
* https://blog.rapid7.com/2018/07/12/how-to-build-your-own-caller-id-spoofer-part-2/

I started with this and decided to strip out all the stuff that I thought was unnecessary to make it more lightweight and secure, and to document the configuration as much as possible.

## Usage

Once set up, here's the basics of using **STUNT BANANA**:

To use the spoofer application:
* From any phone, dial the DID (phone number) you assigned the inbound DISA.
* Key in the passcode you chose, followed by `#`.
* Key in the extension chosen for the spoofer application (`31337` in the sample config) and wait for the prompt
* Then type up to 15 numbers to use as the caller id. Wait for acknowledgement. You should pick an area code and exchange that actually exists otherwise many mobile devices and/or carriers will reject the Caller ID as unauthentic and display 'Unknown' on the device. To display international caller id may require adding a `+` and country code to the beginning. Depending on your carrier and trunk provider, you may need additional prefix digits such as `1` to make things work.
* Then type the number you wish to call. Wait for acknowledgement.
* The number will be dialed now, with your chosen caller id, and you can have a nice conversation when your party picks up the phone.

To use a VOIP phone with the system:
* Install a SIP phone application such as [Zoiper](https://www.zoiper.com/) and follow the instructions below to set up the application.
* Place calls to and from whatever DID you choose to purchase from your SIP trunk provider.
* Dial `*0` to get to the PBX internal DISA dialtone, from which you can call internal extensions and reach the spoofer application, or dial the extensions of any other VOIP phones local to your **STUNT BANANA** installation. Note that while SIP is encrypted here, the audio is still done over RTP which is -not- encrypted. To build a completely private SIP phone, we would need to add VPN capability to **STUNT BANANA**, at which point you might as well just install [Wire](https://wire.com/).
* Zoiper lets you specify caller ID directly in the application, which *is* respected by **STUNT BANANA** specifically, so you can also easily perform ID spoofing that way as well. If the caller ID is not specified in Zoiper, the default caller id specified in the **STUNT BANANA** configuration for this device will be used.
* Text messaging is not supported at this time, however your SIP trunk provider likely has APIs and text-via-email support for allocated DIDs, you might want to set that up outside of **STUNT BANANA** for your users. 

## Setup

* Ensure you have an **AWS** account and you can log into it.
* You might want a mail server you can access to send voicemails from. If you need one, [SendGrid](https://sendgrid.com/) works well and is cheap.
* Provision an **Ubuntu** instance, 18.04/Bionic `ami-06d51e91cea0dac8d` works as of this writing. (`t3.small` should be sufficient in many cases). Other Debian-derived OS may work, but I can't guarantee anything.
* Generate an ssh key on that instance and ensure you can `git clone` from **GitHub** with it.
* Allocate the instance an external EIP
* Prepare a publicly-resolvable domain name for the EIP, with a DNS A record pointing to it.
* SSH into the box and set up the public name as the instance's hostname
  ```
  sudo hostnamectl set-hostname yourname.example.com
  sudo reboot
  ```
* Get yourself an account with a SIP trunk provider (such as **QuestBlue**, don't try to use Twilio for this)
  * provision a SIP trunk with the EIP you allocated for your instance 
  * note down the SIP trunk provider's inbound IP address
  * allocate a DID you would like to use for the [DISA](https://www.asteriskguru.com/tutorials/disa.html) in-dial. This is the number you'll be calling to get access to the spoofer service and any other dialplans you set up.
  * allocate any other DIDs you want to provision for SIP devices/VOIP apps/etc.
* Set up the following security group inbound rules (at least)

  |ports|protocol|addresses|description|
  |-----|--------|---------|-----------|
  |10000-20000|udp|`0.0.0.0/0,::/0`|ports for rtp inbound|
  |5060|udp|`sip.trunk.ip/32`|SIP Trunk UDP inbound|
  |5061|tcp|`0.0.0.0/0,::/0`|SIP over TLS for devices|
  |5060|tcp|`sip.trunk.ip/32`|SIP Trunk TCP inbound|
  |80|tcp|`0.0.0.0/0`|used by **Let's Encrypt** for HTTP auth|
  |443|tcp|`0.0.0.0/0`|used by **Let's Encrypt** for HTTP auth|

  The SIP TCP inbound rule may not be required by your SIP trunk provider.
  The 80/443 ports are intended for use by **Let's Encrypt** to produce SSL certificates used by SIP-over-TLS. This is to protect your devices' SIP accounts from being eavesdropped on or having their credentials stolen.  

  You will also want any rules required to ssh into the machine from a trusted location and access to/from the local VPC if you're in one.

* SSH into the box and clone this repository recursively:
  ```
  git clone --recurse-submodules git@github.com:stuntbanana/stuntbanana.git
  cd stuntbanana
  ```

* Set up **Let's Encrypt**:
  ```
  ./setup-letsencrypt.sh you@youremail.com
  ```
  You'll be providing a contact email for the SSL certificate. If you don't want to use **Let's Encrypt**, skip this step, but you'll need to modify other configuration files to point to your SSL certificates, because you _REALLY_ don't want to run SIP without encryption to your devices. If you get hacked you can easily end up with a $20,000 phone bill.

* Set up **Asterisk**:
  ```
  ./setup-asterisk.sh
  ```
  This may prompt you for what your country's international dialing code. US country code is '1'. If you're elsewhere, [look it up](https://en.wikipedia.org/wiki/List_of_country_calling_codes) and type it in. 
  
  This will install **Asterisk** as a non-root 'asterisk' user. The default branch of **Asterisk** used is a custom fork that has some changes to **pjproject**'s dns resolver. The goal of these changes and many of the default configuration files is to open the minimum number of network-facing TCP/UDP ports and minimize the attack surface. Given that RTP wants to use a large number of high ports for VOIP audio, requiring a large firewall hole, having **pjproject** DNS bind to a random high port is undesirable.

  **Note to devs:** As this is not a general-purpose installation of **Asterisk**, -many- of the modules in `modules.conf` have been disabled to proactively reduce the attack surface. Be aware that changing the dialplan or doing your own development on **STUNT BANANA** may require adding modules to this file. Good luck, sometimes it's not obvious which modules are required. Turning on `autoload=yes` in that file will help determine if a broken script requires a module. 

* Configure **STUNT BANANA**:

  You will need to add a bunch of files by hand to the location `/etc/asterisk/private` to make things work.
  Templates you can use are available at the **Configuration** section of this document.
---

## Configuration

The **Asterisk** configuration for **STUNT BANANA** requires several configuration files to be added manually in the `/etc/asterisk/private` directory. These are `#include`d into the main configuration at various points, and will contain private credentials that have no business in a git repository.

#### /etc/asterisk/private/default-trunk
```
remote_hosts = your.sip.trunk
outbound_auth/username=yourusername
outbound_auth/password=yourpassword
```
This file is in [Asterisk Configuration File](https://wiki.asterisk.org/wiki/display/AST/Asterisk+Configuration+Files) format. 

Replace `your.sip.trunk` with the endpoint of your SIP trunk provider. (for **QuestBlue** this is `sbc.questblue.com` at the time of this writing)

Replace `yourusername` and `yourpassword` with the credentials required by your SIP trunk provider. (for **QuestBlue** this is *name* of your SIP trunk for *both* fields)

#### /etc/asterisk/private/from-internal
```
exten => 31337,1,Goto(spoofer,s,1)
exten => 1000,1,Gosub(internal-dial,s,1(endpoint_name))
```
This file is in [dialplan](https://wiki.asterisk.org/wiki/display/AST/Dialplan) format. 

The first line is the extension to use for the **spoofer** tool. 

The second line is an example of adding an extension for a SIP device. Replace `1000` with the desired extension, and `endpoint_name` with a name for the endpoint. If you have more than one SIP device to provision, you can duplicate this line as many times as necessary with the appropriate changes. If you have no SIP devices, you can remove the second line.

#### /etc/asterisk/private/from-pstn
```
exten => 1235551212,1,Goto(disa,s,1)
exten => 3214442323,1,Goto(from-internal,1000,1)
```
This file is in [dialplan](https://wiki.asterisk.org/wiki/display/AST/Dialplan) format. 

The first line is the DID for the DISA system, telling calls to that number to go the DISA dialplan context.

This second line is for a SIP device, connecting the external phone number to the internal extension specified in the `/etc/asterisk/private/from-internal` file. If you have more than one SIP device to provision, you can duplicate this line as many times as necessary with the appropriate changes. If you have no SIP devices, you can remove the second line.

#### /etc/asterisk/private/passwd-disa
```
123456
```
This file is in plain text format. 

Seriously, change this value to something secure. It's the password to your DISA system, in plaintext. If someone guesses this you're going to be unhappy. The password must be numeric as it will be keyed in on your phone's dialpad.

#### /etc/asterisk/private/phones
```
[endpoint_name](DefaultPhone)
inbound_auth/username=deviceusername
inbound_auth/password=devicepassword
endpoint/set_var=DEFAULT_CALLERID="Your Name"<3214442323>
endpoint/set_var=VOICEMAIL_BOX=1000
```
This file is in [Asterisk Configuration File](https://wiki.asterisk.org/wiki/display/AST/Asterisk+Configuration+Files) format.

Replace `endpoint_name` with the endpoint name you chose in **/etc/asterisk/private/from-internal** as well as choosing a username, password, and caller id to use for the line. The `VOICEMAIL_BOX` can be set to anything but keeping it the same as the extension chosen for this endpoint would ensure there are no conflicts later if you add more lines. The `deviceusername` and `devicepassword` you choose are going to be the ones you put into the VOIP application to log into the system. If you do not make `deviceusername` the same thing as `endpoint_name` you will have to specify it seperately in your voip configuration

#### /etc/asterisk/private/vm-boxes
```
1000 => 1234,Joe Blow,joe@example.com,,attach=yes|tz=pacific|delete=yes
```
This configuration file is in [Asterisk voicemail.conf context](https://wiki.asterisk.org/wiki/display/AST/Configuring+Voice+Mail+Boxes) format.

The format for each line is:
```
voicemailboxnumber => passcode, name, email, secondary email, options
```
`secondary email` does not need to be specified. `passcode` would be used if accessing the voicemail through a non-trusted path, though this is currently unused. The `voicemailboxnumber` should be the same as chosen in `/etc/asterisk/private/phones` for each SIP device. The email specified will receive copies of voicemails left for the device when busy or unanswered, as MP3 file attachments.

#### /etc/asterisk/private/vm-email
```
fromstring=STUNT BANANA
serveremail=noreply@example.com
```
This configuration file is in [Asterisk voicemail.conf [general]](https://wiki.asterisk.org/wiki/display/AST/Configuring+Voice+Mail+Boxes) format.

The `fromstring` will be used as the name on the 'from' address for voicemail emails. The `serveremail` should be an address you can send email from via your email server.

## Email Setup

To send email from STUNT BANANA you will need to set up a `sendmail` compatible mail transport on your STUNT BANANA installation. The setup scripts automatically install the `ssmtp` package, which provides `sendmail` compatibility without needing to run an email daemon. You will need an external email provider, one that works well is `sendgrid`.

To configure email, edit this file:
#### /etc/ssmtp/ssmtp.conf
```
mailhub=mailserver:port
UseSTARTTLS=YES
FromLineOverride=YES
AuthUser=authuser
AuthPass=authpassword
TLS_CA_File=/etc/ssl/certs/ca-certificates.crt
```

`mailserver:port` should be set to an email server you have access to. Avoid port 25 since you'll need to work with Amazon Support to get outbound access to that port. For sendgrid, it's `smtp.sendgrid.net:587`.
`authuser` is your username or api key for the email server
`authpassword` is your password or api secret for the email server

## Zoiper Setup

A word of caution, there are -two- **Zoiper** apps in the Apple App Store. If you intend to purchase **Zoiper Premium**, you might be better off just getting the seperate **Zoiper Premium** app rather than subscribing via **Zoiper Lite**. The subscription to one will not get you access to the other.

If you have **Zoiper Premium**, you can turn on **Incoming Calls/Push Notifications** so your registered SIP phone will receive calls even when the app is sleeping. Push Transport should be set to TCP, as TLS transport for some reason -does not work-. This is only for the push notifications themselves not the SIP/RTP traffic.

### Create an Account
* **Account name** can be anything but for convenience, you might want to name it the same thing as your DID, so you always remember which phone numer you're coming from.
* Your **Domain** should be the hostname of your **STUNT BANANA** installation.
* **User name** should be the `endpoint_name` chosen in `/etc/asterisk/private/phones`
* **Password** should be the `devicepassword` chosen in `/etc/asterisk/private/phones`
* **Caller ID** can be left blank to use the `DEFAULT_CALLERID` chosen in `/etc/asterisk/private/phones` or specified in either numeric or `"Full Name"<Phone Number>` format.
* **Auth Username** needs to be specified as `deviceusername` if it is not the same as `endpoint_name`
* **Network Settings/Transports** should be set to **TLS**. Enable whatever the app tells you to at this point.
* **Network Settings/Protocol suite** should be set to **TLS v1**
* **Number rewriting** should be turned on for your convenience unless it's giving you trouble

