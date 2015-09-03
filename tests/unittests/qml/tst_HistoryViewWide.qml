/*
 * Copyright 2015 Canonical Ltd.
 *
 * This file is part of webbrowser-app.
 *
 * webbrowser-app is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * webbrowser-app is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.4
import QtTest 1.0
import Ubuntu.Components 1.3
import Ubuntu.Components.ListItems 1.3 as ListItems
import Ubuntu.Test 1.0
import webbrowsertest.private 0.1
import webbrowserapp.private 0.1
import "../../../src/app/webbrowser"

Item {
    id: root

    width: 700
    height: 500

    property var historyViewWide: historyViewWideLoader.item

    Loader {
        id: historyViewWideLoader
        anchors.fill: parent
        active: false
        sourceComponent: HistoryViewWide {
            id: historyViewWideComponent
            anchors.fill: parent
            historyModel: HistoryModelTest {
                id: historyMockModel
                databasePath: ":memory:"
            }
        }
    }

    SignalSpy {
        id: doneSpy
        target: historyViewWide
        signalName: "done"
    }

    SignalSpy {
        id: newTabRequestedSpy
        target: historyViewWide
        signalName: "newTabRequested"
    }

    SignalSpy {
        id: historyEntryClickedSpy
        target: historyViewWide
        signalName: "historyEntryClicked"
    }

    UbuntuTestCase {
        name: "HistoryViewWide"
        when: windowShown

        function clickItem(item) {
            var center = centerOf(item)
            mouseClick(item, center.x, center.y)
        }

        function longPressItem(item) {
            var center = centerOf(item)
            mousePress(item, center.x, center.y)
            mouseRelease(item, center.x, center.y, Qt.LeftButton, Qt.NoModifier, 2000)
        }

        function swipeItemRight(item) {
            var center = centerOf(item)
            mousePress(item, center.x, center.y)
            mouseRelease(item, center.x + 100, center.y, Qt.LeftButton, Qt.NoModifier, 2000)
        }

        function init() {
            historyViewWideLoader.active = true
            waitForRendering(historyViewWideLoader.item)

            for (var i = 0; i < 3; ++i) {
                historyViewWide.historyModel.add("http://example.org/" + i, "Example Domain " + i, "")
            }
            var urlsList = findChild(historyViewWide, "urlsListView")
            waitForRendering(urlsList)
            tryCompare(urlsList, "count", 3)
            historyViewWide.forceActiveFocus()
        }

        function cleanup() {
            historyViewWideLoader.active = false
        }

        function getListItems(name, itemName) {
            var list = findChild(historyViewWide, name)
            var items = []
            if (list) {
                // ensure all the delegates are created
                list.cacheBuffer = list.count * 1000

                // In some cases the ListView might add other children to the
                // contentItem, so we filter the list of children to include
                // only actual delegates
                var children = list.contentItem.children
                for (var i = 0; i < children.length; i++) {
                    if (children[i].objectName === itemName) {
                        items.push(children[i])
                    }
                }
            }
            return items
        }

        function test_done_button() {
            var doneButton = findChild(historyViewWide, "doneButton")
            verify(doneButton != null)
            doneSpy.clear()
            clickItem(doneButton)
            compare(doneSpy.count, 1)
        }

        function test_new_tab_button() {
            var newTabButton = findChild(historyViewWide, "newTabButton")
            verify(newTabButton != null)
            doneSpy.clear()
            newTabRequestedSpy.clear()
            clickItem(newTabButton)
            compare(newTabRequestedSpy.count, 1)
            compare(doneSpy.count, 1)
        }

        function test_history_entry_clicked() {
            var urlsList = findChild(historyViewWide, "urlsListView")
            compare(urlsList.count, 3)
            historyEntryClickedSpy.clear()
            clickItem(urlsList.children[0])
            compare(historyEntryClickedSpy.count, 1)
            var args = historyEntryClickedSpy.signalArguments[0]
            var entry = urlsList.model.get(0)
            compare(args[0], entry.url)
        }

        function test_selection_mode() {
            var urlsList = findChild(historyViewWide, "urlsListView")
            compare(urlsList.count, 3)
            var backButton = findChild(historyViewWide, "backButton")
            var selectButton = findChild(historyViewWide, "selectButton")
            var deleteButton = findChild(historyViewWide, "deleteButton")
            verify(!backButton.visible)
            verify(!selectButton.visible)
            verify(!deleteButton.visible)
            longPressItem(urlsList.children[0])
            verify(backButton.visible)
            verify(selectButton.visible)
            verify(deleteButton.visible)
            clickItem(backButton)
            verify(!backButton.visible)
            verify(!selectButton.visible)
            verify(!deleteButton.visible)
        }

        function test_toggle_select_button() {
            var urlsList = findChild(historyViewWide, "urlsListView")
            compare(urlsList.count, 3)
            longPressItem(urlsList.children[0])
            var selectedIndices = urlsList.ViewItems.selectedIndices
            compare(selectedIndices.length, 1)
            var selectButton = findChild(historyViewWide, "selectButton")
            clickItem(selectButton)
            compare(selectedIndices.length, urlsList.count)
            clickItem(selectButton)
            var backButton = findChild(historyViewWide, "backButton")
            clickItem(backButton)
        }

        function test_delete_button() {
            var urlsList = findChild(historyViewWide, "urlsListView")
            compare(urlsList.count, 3)
            var deletedUrl = urlsList.model.get(0).url
            longPressItem(urlsList.children[0])
            var deleteButton = findChild(historyViewWide, "deleteButton")
            clickItem(deleteButton)
            compare(urlsList.count, 2)
            for (var i = 0; i < urlsList.count; ++i) {
                verify(urlsList.model.get(i).url != deletedUrl)
            }
        }

        function test_keyboard_navigation_between_lists() {
            var lastVisitDateList = findChild(historyViewWide, "lastVisitDateListView")
            var urlsList = findChild(historyViewWide, "urlsListView")
            verify(urlsList.activeFocus)
            keyClick(Qt.Key_Left)
            verify(lastVisitDateList.activeFocus)
            verify(!urlsList.activeFocus)
            keyClick(Qt.Key_Right)
            verify(urlsList.activeFocus)
        }

        function test_search_button() {
            var searchButton = findChild(historyViewWide, "searchButton")
            verify(searchButton.visible)
            clickItem(searchButton)
            verify(!searchButton.visible)

            var searchQuery = findChild(historyViewWide, "searchQuery")
            verify(searchQuery.visible)
            verify(searchQuery.activeFocus)
            compare(searchQuery.text, "")

            var urlsList = findChild(historyViewWide, "urlsListView")
            compare(urlsList.count, 3)
            typeString("2")
            compare(urlsList.count, 1)

            var backButton = findChild(historyViewWide, "backButton")
            verify(backButton.visible)
            clickItem(backButton)
            verify(!backButton.visible)
            verify(!searchQuery.visible)
            verify(searchButton.visible)
            compare(urlsList.count, 3)

            clickItem(searchButton)
            compare(searchQuery.text, "")
        }

        function test_keyboard_navigation_for_search() {
            var urlsList = findChild(historyViewWide, "urlsListView")
            verify(urlsList.activeFocus)
            keyClick(Qt.Key_F, Qt.ControlModifier)

            var searchQuery = findChild(historyViewWide, "searchQuery")
            verify(searchQuery.activeFocus)

            keyClick(Qt.Key_Escape)
            verify(urlsList.activeFocus)

            keyClick(Qt.Key_F, Qt.ControlModifier)
            keyClick(Qt.Key_Down)
            verify(urlsList.activeFocus)
            keyClick(Qt.Key_Up)
            verify(searchQuery.activeFocus)

            keyClick(Qt.Key_Down)
            keyClick(Qt.Key_Left)
            keyClick(Qt.Key_Up)
            verify(searchQuery.activeFocus)
        }

        function test_search_highlight() {
            function wraphtml(text) { return "<html>%1</html>".arg(text) }
            function highlight(term) {
                return "<font color=\"%1\">%2</font>".arg("#752571").arg(term)
            }

            var searchButton = findChild(historyViewWide, "searchButton")
            var searchQuery = findChild(historyViewWide, "searchQuery")
            var urlsList = findChild(historyViewWide, "urlsListView")
            clickItem(searchButton)

            var term = "2"
            typeString(term)
            var items = getListItems("urlsListView", "historyDelegate")
            compare(items.length, 1)
            compare(items[0].title, wraphtml("Example Domain " + highlight(term)))

            var backButton = findChild(historyViewWide, "backButton")
            clickItem(backButton)
            clickItem(searchButton)

            var terms = ["1", "Example"]
            typeString(terms.join(" "))
            items = getListItems("urlsListView", "historyDelegate")
            compare(items.length, 1)
            compare(items[0].title, wraphtml("%1 Domain %0"
                                             .arg(highlight(terms[0]))
                                             .arg(highlight(terms[1]))))
        }

        function test_search_updates_dates_list() {
            var today = new Date()
            today = new Date(today.getFullYear(), today.getMonth(), today.getDate())
            function isToday(item) { return item.lastVisitDate.valueOf() === today.valueOf() }
            var oldest = new Date(1903, 6, 14)
            var model = historyViewWide.historyModel
            model.addByDate("https://en.wikipedia.org/wiki/Alan_Turing", "Alan Turing", new Date(1912, 6, 23));
            model.addByDate("https://en.wikipedia.org/wiki/Alonzo_Church", "Alonzo Church", oldest);

            var lastVisitDateList = findChild(historyViewWide, "lastVisitDateListView")
            var dates = getListItems("lastVisitDateListView", "lastVisitDateDelegate")
            var urls = getListItems("urlsListView", "historyDelegate")
            compare(dates.length, 4)
            var todayItem = dates.filter(isToday)
            compare(todayItem.length, 1)
            todayItem = todayItem.pop()
            compare(urls.length, 5)

            // select an date that will not appear after the search
            clickItem(todayItem)
            verify(todayItem.activeFocus)
            keyClick(Qt.Key_F, Qt.ControlModifier)
            typeString("wiki")

            dates = getListItems("lastVisitDateListView", "lastVisitDateDelegate")
            urls = getListItems("urlsListView", "historyDelegate")
            compare(dates.length, 3)
            verify(!dates.some(isToday))
            verify(!todayItem.activeFocus)

            // verify that the last item in the date list is now selected
            compare(dates[dates.length - 1].lastVisitDate.valueOf(), oldest.valueOf())
            compare(urls.length, 1)

            // click on "all dates" and verify that all two search results are present
            clickItem(dates[0])
            urls = getListItems("urlsListView", "historyDelegate")
            compare(urls.length, 2)
        }

        function test_delete_key_at_urls_list_view() {
            var urlsList = findChild(historyViewWide, "urlsListView")
            keyClick(Qt.Key_Right)
            verify(urlsList.activeFocus)
            compare(urlsList.count, 3)
            keyClick(Qt.Key_Delete)
            compare(urlsList.count, 2)
        }

        function test_delete_key_at_last_visit_date() {
            var lastVisitDateList = findChild(historyViewWide, "lastVisitDateListView")
            var urlsList = findChild(historyViewWide, "urlsListView")
            keyClick(Qt.Key_Left)
            verify(lastVisitDateList.activeFocus)
            compare(lastVisitDateList.currentIndex, 0)
            keyClick(Qt.Key_Down)
            compare(lastVisitDateList.currentIndex, 1)
            compare(urlsList.count, 3)
            keyClick(Qt.Key_Delete)
            compare(urlsList.count, 0)
        }

        function test_delete_key_at_all_history() {
            var lastVisitDateList = findChild(historyViewWide, "lastVisitDateListView")
            var urlsList = findChild(historyViewWide, "urlsListView")
            keyClick(Qt.Key_Left)
            verify(lastVisitDateList.activeFocus)
            compare(lastVisitDateList.currentIndex, 0)
            compare(urlsList.count, 3)
            keyClick(Qt.Key_Delete)
            compare(urlsList.count, 0)
        }
    }
}
