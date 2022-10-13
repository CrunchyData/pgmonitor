Changelog Fragment Categories
=============================

This document describes the section categories created in the default config.

The categories are the same as the ones in the `Ansible-case changelog fragments <https://docs.ansible.com/ansible/devel/community/development_process.html#changelogs-how-to>`_.

Note the use of _double backticks_ inside the fragments. This is required if you want the rendered output to contain backticks.

The full list of categories is:

**release_summary**
  This is a special section: as opposed to a list of strings, it accepts one string. This string will be inserted at the top of the changelog entry for the current version, before any section. There can only be one fragment with a ``release_summary`` section.

**breaking_changes**
  This category should list all changes to features which absolutely require attention from users when upgrading, because an existing behavior is changed. This section should only appear in a initial major release (`x.0.0`) according to semantic versioning.

**major_changes**
  This category contains major changes to the project. It should only contain a few items per major version, describing high-level changes. This section should not appear in patch releases according to semantic versioning.

**minor_changes**
  This category should mention all new features not contained elsewhere. This section should not appear in patch releases according to semantic versioning.

**removed_features**
  This category should mention all features that have been removed in this release. This section should only appear in a initial major release (`x.0.0`) according to semantic versioning.

**deprecated_features**
  This category should contain all features which have been deprecated and will be removed in a future release. This section should not appear in patch releases according to semantic versioning.

**security_fixes**
  This category should mention all security relevant fixes, including CVEs if available.

**bugfixes**
  This category should be a list of all bug fixes which fix a bug that was present in a previous version.

**known_issues**
  This category should mention known issues that are currently not fixed or will not be fixed.

**trivial**
  This category will **not be shown** in the changelog. It can be used to describe changes that are not touching user-facing code, like changes in tests. This is useful if every PR is required to have a changelog fragment.

Examples
--------

A guide on how to write changelog fragments can be found in the `Ansible docs <https://docs.ansible.com/ansible/devel/community/development_process.html#changelogs-how-to>`_.

Example of a regular changelog fragment::

    bugfixes:
      - crunchydata.pg.backrest - wait for removal of repoN (https://github.com/CrunchyData/priv-all-ansible-roles/issues/65811).

The filename in this case was ``changelogs/fragments/65854-backrest-wait-for-removal.yml``, because this was implemented in `PR #65854`_.

A fragment can also contain multiple sections, or multiple entries in one section::

    deprecated_features:
    - docker_container - the ``trust_image_content`` option will be removed. It has always been ignored by the module.
    - docker_stack - the return values ``err`` and ``out`` have been deprecated. Use ``stdout`` and ``stderr`` from now on instead.

    breaking_changes:
    - "docker_container - no longer passes information on non-anonymous volumes or binds as ``Volumes`` to the Docker daemon. This increases compatibility with the ``docker`` CLI program. Note that if you specify ``volumes: strict`` in ``comparisons``, this could cause existing containers created with docker_container from Ansible 2.9 or earlier to restart."

The ``release_summary`` section is special, in that it doesn't contain a list of strings, but a string, and that only one such entry can be shown in the changelog of a release. Usually for every release (pre-release or regular release), at most one fragment is added which contains a ``release_summary``, and this is only done by the person doing the release. The ``release_summary`` should include some global information on the release; for example, it always mentions the release date and links to the user guide.

An example of how a fragment with ``release_summary`` could look like::

    release_summary: |
      This is the first proper release of ``antsibull-changelog`` on 2020-06-20.
