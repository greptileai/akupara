## Custom Domains

We use a reverse proxy service [Caddy](https://caddyserver.com/docs/) to route requests to the correct services on our application. The entire Caddy configuration lives in `docker/Caddyfile`. 

According to the instructions in `docker/terraform/README-TF.md` your Caddyfile should look something like 

```
http://<your_ip_address>:8080 {
	handle /api/* {
		reverse_proxy hatchet-api:8080
	}

	handle /* {
		reverse_proxy hatchet-frontend:80
	}
}
```

If you want to add a custom domain to this configuration 
- Add a A record in your DNS records that point `<custom domain> -> <ip address of EC2>`
- Add the following block to your Caddyfile

```
https://CustomGreptileDomain.com {
        handle /* {
                reverse_proxy greptile_web_service:3000
        }
}
```
- Restart the caddy service via `docker compose up --force-recreate -d caddy`

This will correctly route your requests to the greptile web service. 

**Note**: that there is no step that explicitly obtains TLS certificates. This is because caddy does this [automatically](https://caddyserver.com/docs/automatic-https) using Let's Encrypt. This assumes that your ec2 has egress access to the public internet. If you do not allow this, you will need to obtain TLS certificates in a different way. Caddy offers [several options](https://caddyserver.com/docs/caddyfile/directives/tls#:~:text=Use%20a%20custom%20certificate%20and%20key)


## Custom Domain for SSO set up page
We support SSO sign in via [BOXYHQ](https://boxyhq.com/docs/jackson/overview) running in the `greptile_jackson_service`. Signing into the Jackson admin console requires a `HTTPS` connection so we will need to set up a custom domain simmilar to above. Add the following block to your `Caddyfile`

```
https://customJacksonDomain.com {
        handle /* {
                reverse_proxy greptile_jackson_service:5225
        }
}
```

