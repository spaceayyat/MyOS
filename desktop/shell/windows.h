#pragma once

#include <QObject>
#include <QVariantList>
#include <memory>
#include <vector>

struct wl_registry;
struct zwlr_foreign_toplevel_manager_v1;

// Open application windows, as reported by the compositor through
// wlr-foreign-toplevel-management. Empty if the compositor does not offer it.
class Windows : public QObject
{
    Q_OBJECT
    // Each entry: id (int), appId (string), active (bool), minimized (bool).
    Q_PROPERTY(QVariantList list READ list NOTIFY listChanged)
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)

public:
    struct Toplevel;

    explicit Windows(QObject *parent = nullptr);
    ~Windows() override;

    QVariantList list() const { return m_list; }
    bool available() const { return m_manager != nullptr; }

    Q_INVOKABLE void activate(int id);
    Q_INVOKABLE void minimize(int id);
    Q_INVOKABLE void close(int id);

    // Called by the protocol listeners.
    void bind(wl_registry *registry, uint32_t name, uint32_t version);
    void add(struct zwlr_foreign_toplevel_handle_v1 *handle);
    void remove(Toplevel *toplevel);
    void publish();

signals:
    void listChanged();
    void availableChanged();

private:
    Toplevel *find(int id) const;

    wl_registry *m_registry = nullptr;
    zwlr_foreign_toplevel_manager_v1 *m_manager = nullptr;
    std::vector<std::unique_ptr<Toplevel>> m_toplevels;
    QVariantList m_list;
    int m_nextId = 1;
};
