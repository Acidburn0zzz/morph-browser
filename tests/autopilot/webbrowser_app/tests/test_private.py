# -*- Mode: Python; coding: utf-8; indent-tabs-mode: nil; tab-width: 4 -*-
#
# Copyright 2015-2016 Canonical
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 3, as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

from testtools.matchers import Equals, NotEquals
from autopilot.matchers import Eventually

from webbrowser_app.tests import StartOpenRemotePageTestCaseBase


class TestPrivateView(StartOpenRemotePageTestCaseBase):

    def test_going_in_and_out_private_mode(self):
        address_bar = self.main_window.address_bar
        self.main_window.enter_private_mode()
        self.assertThat(self.main_window.is_in_private_mode,
                        Eventually(Equals(True)))
        self.assert_number_incognito_webviews_eventually(1)
        self.assertTrue(self.main_window.is_new_private_tab_view_visible())
        self.assertThat(address_bar.activeFocus,
                        Eventually(Equals(self.main_window.wide)))
        self.assertThat(address_bar.text, Eventually(Equals("")))

        self.main_window.leave_private_mode()
        self.assertThat(self.main_window.is_in_private_mode,
                        Eventually(Equals(False)))
        self.assert_number_incognito_webviews_eventually(0)
        self.assertThat(address_bar.text, Eventually(NotEquals("")))
        self.assertThat(address_bar.activeFocus, Eventually(Equals(False)))

    def test_leaving_private_mode_with_multiples_tabs_ask_confirmation(self):
        self.main_window.enter_private_mode()
        self.assertThat(self.main_window.is_in_private_mode,
                        Eventually(Equals(True)))
        self.assertTrue(self.main_window.is_new_private_tab_view_visible())
        if not self.main_window.wide:
            self.open_tabs_view()
        self.open_new_tab()
        self.main_window.leave_private_mode_with_confirmation()
        self.assertThat(self.main_window.is_in_private_mode,
                        Eventually(Equals(False)))

    def test_cancel_leaving_private_mode(self):
        self.main_window.enter_private_mode()
        self.assertThat(self.main_window.is_in_private_mode,
                        Eventually(Equals(True)))
        self.assertTrue(self.main_window.is_new_private_tab_view_visible())
        if not self.main_window.wide:
            self.open_tabs_view()
        self.open_new_tab()
        self.main_window.leave_private_mode_with_confirmation(confirm=False)
        self.assertThat(self.main_window.is_in_private_mode,
                        Eventually(Equals(True)))
        self.assertTrue(self.main_window.is_new_private_tab_view_visible())

    def test_url_showing_in_top_sites_in_and_out_private_mode(self):
        new_tab = self.open_new_tab(open_tabs_view=True)
        urls = [site.url for site in new_tab.get_top_site_items()]
        self.assertIn(self.url, urls)

        self.main_window.enter_private_mode()
        self.assertThat(self.main_window.is_in_private_mode,
                        Eventually(Equals(True)))
        url = self.base_url + "/test2"
        self.main_window.go_to_url(url)
        self.main_window.wait_until_page_loaded(url)
        self.main_window.leave_private_mode()
        self.assertThat(self.main_window.is_in_private_mode,
                        Eventually(Equals(False)))

        new_tab = self.open_new_tab(open_tabs_view=True)
        urls = [site.url for site in new_tab.get_top_site_items()]
        self.assertNotIn(url, urls)

    def test_public_tabs_should_not_be_visible_in_private_mode(self):
        self.open_new_tab(open_tabs_view=True)
        new_tab_view = self.main_window.get_new_tab_view()
        url = self.base_url + "/test2"
        self.main_window.go_to_url(url)
        new_tab_view.wait_until_destroyed()
        if self.main_window.wide:
            tabs = self.main_window.chrome.get_tabs_bar().get_tabs()
            self.assertThat(len(tabs), Equals(2))
        else:
            tabs_view = self.open_tabs_view()
            previews = tabs_view.get_previews()
            self.assertThat(len(previews), Equals(2))
            toolbar = self.main_window.get_recent_view_toolbar()
            toolbar.click_button("doneButton")
            tabs_view.visible.wait_for(False)

        self.main_window.enter_private_mode()
        self.assertThat(self.main_window.is_in_private_mode,
                        Eventually(Equals(True)))
        self.assertTrue(self.main_window.is_new_private_tab_view_visible())
        if self.main_window.wide:
            tabs = self.main_window.chrome.get_tabs_bar().get_tabs()
            self.assertThat(len(tabs), Equals(1))
        else:
            tabs_view = self.open_tabs_view()
            previews = tabs_view.get_previews()
            self.assertThat(len(previews), Equals(1))
