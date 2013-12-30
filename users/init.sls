include:
  - users.sudo

{% for name, user in pillar.get('users', {}).items() %}
{% if user == None %}
{% set user = {} %}
{% endif %}
{% set home = user.get('home', "/home/%s" % name) %}

{% for group in user.get('groups', []) %}
{{ group }}_group:
  group:
    - name: {{ group }}
    - present
{% endfor %}

{{ name }}_user:
  file.directory:
    - name: {{ home }}
    - user: {{ name }}
    - group: {{ name }}
    - mode: 0755
    - require:
      - user: {{ name }}
      - group: {{ name }}
  group.present:
    - name: {{ name }}
    {% if 'uid' in user -%}
    - gid: {{ user['uid'] }}
    {% endif %}
  user.present:
    - name: {{ name }}
    - home: {{ home }}
    - shell: {{ user.get('shell', '/bin/bash') }}
    {% if 'uid' in user -%}
    - uid: {{ user['uid'] }}
    {% endif %}
    - gid_from_name: True
    {% if 'fullname' in user %}
    - fullname: {{ user['fullname'] }}
    {% endif %}
    {% if 'hash' in user %}
    - password: {{ user['hash'] }}
    {% endif %}
    - system: {{ user.get('system', False) }}
    - groups:
        - {{ name }}
      {% for group in user.get('groups', []) %}
        - {{ group }}
      {% endfor %}
    - require:
        - group: {{ name }}
      {% for group in user.get('groups', []) %}
        - group: {{ group }}
      {% endfor %}

user_keydir_{{ name }}:
  file.directory:
    - name: {{ user.get('home', '/home/{0}'.format(name)) }}/.ssh
    - user: {{ name }}
    - group: {{ name }}
    - makedirs: True
    - mode: 744
    - require:
      - user: {{ name }}
      - group: {{ name }}
      {% for group in user.get('groups', []) %}
      - group: {{ group }}
      {% endfor %}

  {% if 'privkey' in user %}
user_{{ name }}_private_key:
  file.managed:
    - name: {{ user.get('home', '/home/{0}'.format(name)) }}/.ssh/id_rsa
    - user: {{ name }}
    - group: {{ name }}
    - mode: 600
    - source: salt://keys/{{ user['privkey'] }}
    - require:
      - user: {{ name }}_user
      {% for group in user.get('groups', []) %}
      - group: {{ group }}_group
      {% endfor %}
user_{{ name }}_public_key:
  file.managed:
    - name: {{ user.get('home', '/home/{0}'.format(name)) }}/.ssh/id_rsa.pub
    - user: {{ name }}
    - group: {{ name }}
    - mode: 644
    - source: salt://keys/{{ user['privkey'] }}.pub
    - require:
      - user: {{ name }}_user
      {% for group in user.get('groups', []) %}
      - group: {{ group }}_group
      {% endfor %}
  {% endif %}


  {% if 'ssh_auth' in user %}
  {% for auth in user['ssh_auth'] %}
ssh_auth_{{ name }}_{{ loop.index0 }}:
  ssh_auth.present:
    - user: {{ name }}
    - name: {{ auth }}
    - require:
        - file: {{ name }}_user
        - user: {{ name }}_user
{% endfor %}
{% endif %}

{% if 'dotfiles' in user %}
{% set dotfiles_dir = home ~ '/.dotfiles' %}

{{ dotfiles_dir }}:
  file.directory:
    - user: {{ name }}
    - group: {{ name }}
    - makedirs: True
    - require:
      - user: {{ name }}_user
      {% for group in user.get('groups', []) %}
      - group: {{ group }}_group
      {% endfor %}

{{ user['dotfiles']['repository'] }}_{{ name }}:
  git.latest:
    - name: {{ user['dotfiles']['repository'] }}
    - target: {{ dotfiles_dir }}
    - user: {{ name }}
    - require:
      - file: {{ dotfiles_dir }}

{{ user['dotfiles']['install_cmd'] }}_{{ name }}:
  cmd.wait:
    - name: {{ user['dotfiles']['install_cmd'] }}
    - user: {{ name }}
    - cwd: {{ dotfiles_dir }}
    - watch:
      - git: {{ user['dotfiles']['repository'] }}_{{ name }}

{% endif %}

{% if 'sudouser' in user and user['sudouser'] %}
sudoer-{{ name }}:
  file.managed:
    - name: /etc/sudoers.d/{{ name }}
    - user: root
    - group: root
    - mode: '0440'
/etc/sudoers.d/{{ name }}:
  file.append:
  - text:
    - "{{ name }}    ALL=(ALL)  NOPASSWD: ALL"
  - require:
    - file: sudoer-defaults
    - file: sudoer-{{ name }}
{% else %}
/etc/sudoers.d/{{ name }}:
  file.absent:
    - name: /etc/sudoers.d/{{ name }}
{% endif %}

{% endfor %}

{% for user in pillar.get('absent_users', []) %}
{{ user }}:
  user.absent
/etc/sudoers.d/{{ user }}:
  file.absent:
    - name: /etc/sudoers.d/{{ user }}
{% endfor %}
