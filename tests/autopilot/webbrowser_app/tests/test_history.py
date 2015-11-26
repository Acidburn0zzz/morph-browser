# -*- Mode: Python; coding: utf-8; indent-tabs-mode: nil; tab-width: 4 -*-
#
# Copyright 2015 Canonical
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

import time

from testtools.matchers import Equals
from autopilot.matchers import Eventually

from webbrowser_app.tests import StartOpenRemotePageTestCaseBase


class TestHistory(StartOpenRemotePageTestCaseBase):

    def test_history_not_save_404(self):
        url = self.base_url + "/404page"
        self.main_window.go_to_url(url)
        self.main_window.wait_until_page_loaded(url)

        # A valid url to be sure the fact the 404 page isn't present in the
        # history view isn't a timing issue.
        url = self.base_url + "/test2"
        self.main_window.go_to_url(url)
        self.main_window.wait_until_page_loaded(url)

        history = self.open_history()

        # We have domains with subsections only on mobiles.
        # On wide we take all the entries directly
        if self.main_window.wide:
            delegates = history.get_entries()

            # 2 addresses: /test1 and /test2
            self.assertThat(lambda: len(history.get_entries()),
                            Eventually(Equals(2)))
            self.assertThat(sorted([delegate.url for delegate in delegates]),
                            Equals(sorted([self.url, url])))
        else:
            # 1 domain: the local one
            domain_entries = history.get_domain_entries()
            self.assertThat(lambda: len(history.get_domain_entries()),
                            Eventually(Equals(1)))

            self.pointing_device.click_object(domain_entries[0])
            expanded_history = self.main_window.get_expanded_history_view()

            # 2 addresses: /test1 and /test2
            self.assertThat(lambda: len(expanded_history.get_entries()),
                            Eventually(Equals(2)))

            delegates = expanded_history.get_entries()
            self.assertThat(sorted([delegate.url for delegate in delegates]),
                            Equals(sorted([self.url, url])))

    def test_expanded_history_view_header_swallows_clicks(self):
        # Regression test for https://launchpad.net/bugs/1518904
        if self.main_window.wide:
            self.skipTest("Only on narrow form factors")
        history = self.open_history()
        self.pointing_device.click_object(history.get_domain_entries()[0])
        expanded_history = self.main_window.get_expanded_history_view()
        hr = expanded_history.get_header().globalRect
        self.pointing_device.move(hr.x + hr.width // 2, hr.y + hr.height - 5)
        self.pointing_device.click()
        time.sleep(1)
        # There should be only one instance on the expanded history view.
        # If there’s more, the following call will raise an exception.
        self.main_window.get_expanded_history_view()
