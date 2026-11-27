import QtQuick

// This month at a glance.
Card {
    id: root
    MonthView { theme: root.theme; width: parent.width }
}
