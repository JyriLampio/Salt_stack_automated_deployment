install ufw:
  pkg.installed:
    - name: ufw

ufw allow 80/tcp:
  cmd.run:
    - unless: "ufw status verbose | grep '80/tcp'"

ufw allow 443/tcp:
  cmd.run:
    - unless: "ufw status verbose | grep '443/tcp'"

ufw enable:
  cmd.run:
    - unless: "ufw status | grep 'Status: active'"

install_caddy_dependencies:
  pkg.installed:
    - pkgs:
      - debian-keyring
      - debian-archive-keyring
      - apt-transport-https

imported_caddy_key:
  cmd.run:
    - name: curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    - creates: /usr/share/keyrings/caddy-stable-archive-keyring.gpg

added_caddy_repo:
  cmd.run:
    - name: curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
    - creates: /etc/apt/sources.list.d/caddy-stable.list

install_docker_prerequisites:
  file.directory:
    - name: /etc/apt/keyrings
    - mode: '0755'

  cmd.run:
    - name: curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    - creates: /etc/apt/keyrings/docker.gpg

/etc/apt/keyrings/docker.gpg:
  file.managed:
    - mode: 0644
    - replace: false

add_docker_repo:
  cmd.run:
    - name: |
        echo \
        "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
        "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    - unless: grep -q "docker" /etc/apt/sources.list.d/docker.list
    - require:
      - cmd: install_docker_prerequisites

update_repositories:
  cmd.run:
    - name: sudo apt update
    - require:
      - cmd: imported_caddy_key
      - cmd: added_caddy_repo

install_caddy:
  pkg.installed:
    - pkgs:
      - caddy
    - require:
      - pkg: install_caddy_dependencies
      - cmd: imported_caddy_key
      - cmd: added_caddy_repo

/etc/caddy:
  file.directory:
    - name:  /etc/caddy
    - mode:  755

/etc/caddy/Caddyfile:
  file.managed:
    - source: salt://ohtuprojekti/Caddyfile

start_caddy:
  service.running:
    - name: caddy
    - watch:
      - pkg: install_caddy

remove_old_docker:
  pkg.removed:
    - pkgs:
      - docker 
      - docker-engine
      - docker.io 
      - containerd 
      - runc

add_docker_repository_dependencies:
  pkg.installed:
    - pkgs:
      - ca-certificates
      - curl
      - gnupg

install_docker:
  pkg.installed:
    - pkgs:
      - docker-ce
      - docker-ce-cli
      - containerd.io
      - docker-buildx-plugin
      - docker-compose-plugin

start_docker:
  service.running:
    - name: docker

create_docker_container:
  cmd.run:
    - name: sudo docker compose up
    - cwd: /srv/salt/ohtuprojekti/DCP-Server
    - bg: true
    - unless: "sudo docker images | grep dcp-server"
    - require:
      - service: start_docker