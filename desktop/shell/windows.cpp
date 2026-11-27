#include "windows.h"

#include <QGuiApplication>
#include <QString>
#include <QVariantMap>
#include <algorithm>
#include <cstring>

#include <wayland-client.h>

#include "wlr-foreign-toplevel-management-unstable-v1-client-protocol.h"

struct Windows::Toplevel
{
    Windows *owner;
    zwlr_foreign_toplevel_handle_v1 *handle;
    int id;
    QString appId;
    bool active = false;
    bool minimized = false;
    bool ready = false; // true after the first "done"
};

namespace {

using Toplevel = Windows::Toplevel;

void onTitle(void *, zwlr_foreign_toplevel_handle_v1 *, const char *) {}

void onAppId(void *data, zwlr_foreign_toplevel_handle_v1 *, const char *appId)
{
    static_cast<Toplevel *>(data)->appId = QString::fromUtf8(appId);
}

void onOutputEnter(void *, zwlr_foreign_toplevel_handle_v1 *, wl_output *) {}
void onOutputLeave(void *, zwlr_foreign_toplevel_handle_v1 *, wl_output *) {}

void onState(void *data, zwlr_foreign_toplevel_handle_v1 *, wl_array *states)
{
    auto *t = static_cast<Toplevel *>(data);
    t->active = false;
    t->minimized = false;
    const auto *values = static_cast<const uint32_t *>(states->data);
    for (size_t i = 0; i < states->size / sizeof(uint32_t); ++i) {
        if (values[i] == ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_ACTIVATED)
            t->active = true;
        else if (values[i] == ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_MINIMIZED)
            t->minimized = true;
    }
}

void onDone(void *data, zwlr_foreign_toplevel_handle_v1 *)
{
    auto *t = static_cast<Toplevel *>(data);
    t->ready = true;
    t->owner->publish();
}

void onClosed(void *data, zwlr_foreign_toplevel_handle_v1 *)
{
    auto *t = static_cast<Toplevel *>(data);
    t->owner->remove(t);
}

void onParent(void *, zwlr_foreign_toplevel_handle_v1 *, zwlr_foreign_toplevel_handle_v1 *) {}

const zwlr_foreign_toplevel_handle_v1_listener handleListener = {
    onTitle, onAppId, onOutputEnter, onOutputLeave, onState, onDone, onClosed, onParent};

void onToplevel(void *data, zwlr_foreign_toplevel_manager_v1 *, zwlr_foreign_toplevel_handle_v1 *handle)
{
    static_cast<Windows *>(data)->add(handle);
}

void onFinished(void *, zwlr_foreign_toplevel_manager_v1 *) {}

const zwlr_foreign_toplevel_manager_v1_listener managerListener = {onToplevel, onFinished};

void onGlobal(void *data, wl_registry *registry, uint32_t name, const char *interface, uint32_t version)
{
    if (std::strcmp(interface, zwlr_foreign_toplevel_manager_v1_interface.name) == 0)
        static_cast<Windows *>(data)->bind(registry, name, version);
}

void onGlobalRemove(void *, wl_registry *, uint32_t) {}

const wl_registry_listener registryListener = {onGlobal, onGlobalRemove};

QNativeInterface::QWaylandApplication *wayland()
{
    return qGuiApp->nativeInterface<QNativeInterface::QWaylandApplication>();
}

} // namespace

Windows::Windows(QObject *parent)
    : QObject(parent)
{
    auto *native = wayland();
    if (!native || !native->display())
        return;
    // Qt's event loop dispatches the replies.
    m_registry = wl_display_get_registry(native->display());
    wl_registry_add_listener(m_registry, &registryListener, this);
    wl_display_flush(native->display());
}

// The connection closes with the process, which releases every protocol object.
Windows::~Windows() = default;

void Windows::bind(wl_registry *registry, uint32_t name, uint32_t version)
{
    m_manager = static_cast<zwlr_foreign_toplevel_manager_v1 *>(wl_registry_bind(
        registry, name, &zwlr_foreign_toplevel_manager_v1_interface, std::min(version, 3u)));
    zwlr_foreign_toplevel_manager_v1_add_listener(m_manager, &managerListener, this);
    emit availableChanged();
}

void Windows::add(zwlr_foreign_toplevel_handle_v1 *handle)
{
    m_toplevels.push_back(std::make_unique<Toplevel>(Toplevel{this, handle, m_nextId++, {}}));
    zwlr_foreign_toplevel_handle_v1_add_listener(handle, &handleListener, m_toplevels.back().get());
}

void Windows::remove(Toplevel *toplevel)
{
    zwlr_foreign_toplevel_handle_v1_destroy(toplevel->handle);
    m_toplevels.erase(std::remove_if(m_toplevels.begin(), m_toplevels.end(),
                                     [toplevel](const auto &t) { return t.get() == toplevel; }),
                      m_toplevels.end());
    publish();
}

void Windows::publish()
{
    QVariantList list;
    for (const auto &t : m_toplevels) {
        if (!t->ready)
            continue;
        list.append(QVariantMap{{QStringLiteral("id"), t->id},
                                {QStringLiteral("appId"), t->appId},
                                {QStringLiteral("active"), t->active},
                                {QStringLiteral("minimized"), t->minimized}});
    }
    if (list == m_list) // title changes alone do not redraw the dock
        return;
    m_list = list;
    emit listChanged();
}

Windows::Toplevel *Windows::find(int id) const
{
    for (const auto &t : m_toplevels) {
        if (t->id == id)
            return t.get();
    }
    return nullptr;
}

void Windows::activate(int id)
{
    auto *native = wayland();
    Toplevel *t = find(id);
    if (!t || !native || !native->seat())
        return;
    zwlr_foreign_toplevel_handle_v1_unset_minimized(t->handle);
    zwlr_foreign_toplevel_handle_v1_activate(t->handle, native->seat());
    wl_display_flush(native->display());
}

void Windows::minimize(int id)
{
    if (Toplevel *t = find(id)) {
        zwlr_foreign_toplevel_handle_v1_set_minimized(t->handle);
        wl_display_flush(wayland()->display());
    }
}

void Windows::close(int id)
{
    if (Toplevel *t = find(id)) {
        zwlr_foreign_toplevel_handle_v1_close(t->handle);
        wl_display_flush(wayland()->display());
    }
}
