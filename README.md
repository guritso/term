# term

A static minimalist site with latest animes and github repositories.

## dev

```bash
python -m http.server 8081

# http://127.0.0.1:8081

# you can inject this in your dev tools console
fetch('/pages/autoindex-header.html')
  .then(r => r.text())
  .then(html => document.body.insertAdjacentHTML('afterbegin', html));

```

## Deploy

```
sudo ./deploy.sh

# /usr/share/nginx/html
# http://localhost:80
```

## Crontab

Every 12 hours
```
* */12 * * * /usr/share/nginx/html/scripts/index.sh

```

See `./nginx.conf`, `./deploy.sh` and `scripts/index.sh`
