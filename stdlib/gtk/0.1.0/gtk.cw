namespace Gtk {
    class Config {
        String validate(String text)
        String fileStatus(String path)
        String value(String text, String section, String key)
        String key(String text, String section, int64 index)
        String quote(String text)
        String merge(String original, String updates)
        String remove(String text, String section, String key)
        String item(String text, String section, String key, int64 index, String field)
        int64 arraySize(String text, String section, String key)
        void save(String path, String text, String expected, callback<void(String)> result)
        String saveNow(String path, String text, String expected)
    }
    String Config.validate(String text) from "cwhip_gtk_config_validate"
    String Config.fileStatus(String path) from "cwhip_gtk_config_file_status"
    String Config.value(String text, String section, String key) from "cwhip_gtk_config_value"
    String Config.key(String text, String section, int64 index) from "cwhip_gtk_config_key"
    String Config.quote(String text) from "cwhip_gtk_config_quote"
    String Config.merge(String original, String updates) from "cwhip_gtk_config_merge"
    String Config.remove(String text, String section, String key) from "cwhip_gtk_config_remove"
    String Config.item(String text, String section, String key, int64 index, String field)
        from "cwhip_gtk_config_item"
    int64 Config.arraySize(String text, String section, String key) from "cwhip_gtk_config_array_size"
    void Config.save(String path, String text, String expected, callback<void(String)> result)
        from "cwhip_gtk_config_save"
    String Config.saveNow(String path, String text, String expected) from "cwhip_gtk_config_save_now"

    class Keyboard {
        String normalize(String trigger)
        int64 record(Entry entry, callback<void(String)> result)
        bool cancel(int64 token)
    }
    String Keyboard.normalize(String trigger) from "cwhip_gtk_keyboard_normalize"
    int64 Keyboard.record(Entry entry, callback<void(String)> result) from "cwhip_gtk_keyboard_record"
    bool Keyboard.cancel(int64 token) from "cwhip_gtk_keyboard_cancel"

    class Font {
        bool isMonospace(String family)
    }
    bool Font.isMonospace(String family) from "cwhip_gtk_font_is_monospace"
    class Application {
        private:
        void _create(String id)
        Application _self()
        public:
        Application() {}
        Application(String id) { _create(id) }
        void initialize()
        String id()
        SignalConnection onActivate(callback<void()> action) {
            return SignalConnection(_self(), action)
        }
        void run()
        void quit()
        void shutdown()
        void ready()
        int64 post(callback<void()> action)
        bool cancel(int64 token)
    }

    class SignalConnection {
        private:
        int64 _token
        int64 _activate(Application source, callback<void()> action)
        int64 _click(Button source, callback<void()> action)
        int64 _changed(Entry source, callback<void(String)> action)
        int64 _close(Window source, callback<bool()> action)
        int64 _close(TransientWindow source, callback<bool()> action)
        int64 _toggled(CheckButton source, callback<void(bool)> action)
        int64 _pageChanged(Notebook source, callback<void()> action)
        int64 _focusChanged(Window source, callback<void(bool)> action)
        bool _disconnect(int64 token)
        bool _connected(int64 token)
        public:
        SignalConnection(Application source, callback<void()> action) {
            _token = _activate(source, action)
        }
        SignalConnection(Button source, callback<void()> action) {
            _token = _click(source, action)
        }
        SignalConnection(Entry source, callback<void(String)> action) {
            _token = _changed(source, action)
        }
        SignalConnection(Window source, callback<bool()> action) {
            _token = _close(source, action)
        }
        SignalConnection(TransientWindow source, callback<bool()> action) {
            _token = _close(source, action)
        }
        SignalConnection(CheckButton source, callback<void(bool)> action) {
            _token = _toggled(source, action)
        }
        SignalConnection(Notebook source, callback<void()> action) {
            _token = _pageChanged(source, action)
        }
        SignalConnection(Window source, callback<void(bool)> action) {
            _token = _focusChanged(source, action)
        }
        bool disconnect() { return _disconnect(_token) }
        bool connected() { return _connected(_token) }
    }

    class Widget {
        private:
        int64 _id
        Widget _self()
        void _keepAlive() {}
        int64 _create(int64 kind, String text, int64 orientation, int64 spacing, callback<void()> root)
        void _dispose(int64 token)
        bool _disposed(int64 token)
        void _visible(int64 token, bool value)
        void _sensitive(int64 token, bool value)
        void _expand(int64 token, bool horizontal, bool value)
        void _focus(int64 token)
        void _textSet(int64 token, String text)
        String _textGet(int64 token)
        void _attach(int64 parent, int64 child)
        void _remove(int64 parent, int64 child)
        void _windowAction(int64 token, int64 action)
        void _windowSize(int64 token, int64 width, int64 height)
        int64 _windowWidth(int64 token)
        int64 _windowHeight(int64 token)
        void _windowTransientFor(int64 token, int64 parent)
        void _layout(int64 token, int64 orientation, int64 spacing)
        void _activeSet(int64 token, bool value)
        bool _activeGet(int64 token)
        protected:
        void _notebookAppend(int64 notebook, int64 child, String title)
        int64 _notebookCurrent(int64 notebook)
        void _notebookSetCurrent(int64 notebook, int64 page)
        int64 _notebookCount(int64 notebook)
        void _notebookTitle(int64 notebook, int64 page, String title)
        Widget(int64 kind, String text, int64 orientation, int64 spacing) {
            _id = _create(kind, text, orientation, spacing, _self()._keepAlive)
        }
        void _setText(String text) { _textSet(_id, text) }
        String _getText() { return _textGet(_id) }
        void _attachChild(Widget child) { _attach(_id, child._id) }
        void _removeChild(Widget child) { _remove(_id, child._id) }
        void _presentWindow() { _windowAction(_id, 0) }
        void _closeWindow() { _windowAction(_id, 1) }
        void _sizeWindow(int64 width, int64 height) { _windowSize(_id, width, height) }
        int64 _defaultWidth() { return _windowWidth(_id) }
        int64 _defaultHeight() { return _windowHeight(_id) }
        void _setTransientFor(int64 parent) { _windowTransientFor(_id, parent) }
        void _boxLayout(int64 orientation, int64 spacing) { _layout(_id, orientation, spacing) }
        void _setActive(bool value) { _activeSet(_id, value) }
        bool _getActive() { return _activeGet(_id) }
        void _grabFocus() { _focus(_id) }
        public:
        int64 _widgetToken() { return _id }
        void dispose() { _dispose(_id) }
        bool disposed() { return _disposed(_id) }
        void setVisible(bool value) { _visible(_id, value) }
        void setSensitive(bool value) { _sensitive(_id, value) }
        void setHExpand(bool value) { _expand(_id, true, value) }
        void setVExpand(bool value) { _expand(_id, false, value) }
    }

    class Window : Widget {
        private:
        Window _windowSelf()
        bool _bindShortcut(int64 token, String trigger, callback<void()> action)
        bool _hasShortcut(int64 token, String trigger)
        bool _maximized(int64 token)
        void _maximize(int64 token, bool enabled)
        public:
        Window(String title) { super Widget(1, title, 0, 0) }
        void setTitle(String title) { _setText(title) }
        String title() { return _getText() }
        void setDefaultSize(int64 width, int64 height) { _sizeWindow(width, height) }
        int64 defaultWidth() { return _defaultWidth() }
        int64 defaultHeight() { return _defaultHeight() }
        bool maximized() { return _maximized(_widgetToken()) }
        void setMaximized(bool enabled) { _maximize(_widgetToken(), enabled) }
        void setTransientFor(Window parent) {
            _setTransientFor(parent._widgetToken())
        }
        void setChild(Widget child) { _attachChild(child) }
        void remove(Widget child) { _removeChild(child) }
        void present() { _presentWindow() }
        void close() { _closeWindow() }
        // Binds a GTK accelerator such as "<Control>q" for the whole window.
        bool bindShortcut(String trigger, callback<void()> action) {
            return _bindShortcut(_widgetToken(), trigger, action)
        }
        bool hasShortcut(String trigger) { return _hasShortcut(_widgetToken(), trigger) }
        SignalConnection onCloseRequest(callback<bool()> action) {
            return SignalConnection(_windowSelf(), action)
        }
        SignalConnection onFocusChanged(callback<void(bool)> action) {
            return SignalConnection(_windowSelf(), action)
        }
    }

    class TransientWindow : Widget {
        private:
        TransientWindow _transientSelf()
        public:
        TransientWindow(String title) { super Widget(11, title, 0, 0) }
        void setTitle(String title) { _setText(title) }
        String title() { return _getText() }
        void setDefaultSize(int64 width, int64 height) { _sizeWindow(width, height) }
        void setTransientFor(Window parent) {
            _setTransientFor(parent._widgetToken())
        }
        void setChild(Widget child) { _attachChild(child) }
        void remove(Widget child) { _removeChild(child) }
        void present() { _presentWindow() }
        void close() { _closeWindow() }
        SignalConnection onCloseRequest(callback<bool()> action) {
            return SignalConnection(_transientSelf(), action)
        }
    }

    class Box : Widget {
        public:
        enum { HORIZONTAL = 0, VERTICAL = 1 }
        Box(int64 orientation, int64 spacing) { super Widget(2, "", orientation, spacing) }
        void setLayout(int64 orientation, int64 spacing) { _boxLayout(orientation, spacing) }
        void append(Widget child) { _attachChild(child) }
        void remove(Widget child) { _removeChild(child) }
    }

    class Label : Widget {
        public:
        Label(String text) { super Widget(3, text, 0, 0) }
        void setText(String text) { _setText(text) }
        String text() { return _getText() }
    }

    class Grid : Widget {
        private:
        void _attachAt(int64 token, int64 child, int64 column, int64 row, int64 width, int64 height)
        public:
        Grid(int64 spacing) { super Widget(14, "", 0, spacing) }
        void attach(Widget child, int64 column, int64 row, int64 width, int64 height) {
            _attachAt(_widgetToken(), child._widgetToken(), column, row, width, height)
        }
    }

    class ContextMenu : Widget {
        private:
        void _bind(int64 token, int64 owner)
        public:
        ContextMenu(Widget owner) {
            super Widget(15, "", 0, 0)
            _bind(_widgetToken(), owner._widgetToken())
        }
        void setChild(Widget child) { _attachChild(child) }
    }

    class Button : Widget {
        private:
        Button _buttonSelf()
        public:
        Button(String label) { super Widget(4, label, 0, 0) }
        void setLabel(String label) { _setText(label) }
        String label() { return _getText() }
        SignalConnection onClicked(callback<void()> action) {
            return SignalConnection(_buttonSelf(), action)
        }
    }

    class Entry : Widget {
        private:
        Entry _entrySelf()
        void _editable(int64 token, bool editable)
        public:
        Entry(String text) { super Widget(5, text, 0, 0) }
        void setText(String text) { _setText(text) }
        String text() { return _getText() }
        SignalConnection onChanged(callback<void(String)> action) {
            return SignalConnection(_entrySelf(), action)
        }
        void focus() { _grabFocus() }
        void setEditable(bool editable) { _editable(_widgetToken(), editable) }
    }

    class MenuBar : Widget {
        private:
        int64 _addMenu(int64 token, String label)
        int64 _addItem(int64 token, int64 menu, String label, callback<void()> action)
        void _enabled(int64 token, int64 item, bool value)
        void _activate(int64 token, int64 item)
        void _separator(int64 token, int64 menu)
        public:
        MenuBar() { super Widget(10, "", 0, 0) }
        int64 addMenu(String label) { return _addMenu(_widgetToken(), label) }
        int64 addItem(int64 menu, String label, callback<void()> action) {
            return _addItem(_widgetToken(), menu, label, action)
        }
        // Draws a divider before the next item added to menu.
        void addSeparator(int64 menu) { _separator(_widgetToken(), menu) }
        void setItemEnabled(int64 item, bool enabled) { _enabled(_widgetToken(), item, enabled) }
        void activateItem(int64 item) { _activate(_widgetToken(), item) }
    }

    class FileSelection {
        private:
        list _paths
        callback<void(list)> _result
        public:
        FileSelection(callback<void(list)> result) {
            _paths = []
            _result = result
        }
        void add(String path) {
            if (!path.equals("")) {
                _paths.append(path)
                return
            }
            list paths = _paths
            _paths = []
            _result(paths)
        }
    }

    class FileDialog {
        private:
        int64 _token
        FileSelection _selection
        int64 _create(int64 parent, bool save, String initialPath, callback<void(String)> result)
        int64 _createMultiple(int64 parent, String initialPath, callback<void(String)> path)
        int64 _createFolder(int64 parent, String initialPath, callback<void(String)> result)
        void _cancel(int64 token)
        bool _pending(int64 token)
        public:
        FileDialog(Window parent, bool save, String initialPath, callback<void(String)> result) {
            _token = _create(parent._widgetToken(), save, initialPath, result)
        }
        FileDialog(Window parent, String initialPath, callback<void(list)> results) {
            _selection = FileSelection(results)
            _token = _createMultiple(parent._widgetToken(), initialPath, _selection.add)
        }
        FileDialog(Window parent, String initialPath, callback<void(String)> folder) {
            _token = _createFolder(parent._widgetToken(), initialPath, folder)
        }
        void cancel() { _cancel(_token) }
        bool pending() { return _pending(_token) }
    }

    class AlertDialog {
        private:
        void _show(int64 parent, String message, String detail)
        public:
        // Shows a modal error/information alert over parent; it closes itself.
        void show(Window parent, String message, String detail) {
            _show(parent._widgetToken(), message, detail)
        }
    }

    class CheckButton : Widget {
        private:
        CheckButton _checkSelf()
        public:
        CheckButton(String label) { super Widget(6, label, 0, 0) }
        void setLabel(String label) { _setText(label) }
        String label() { return _getText() }
        void setActive(bool value) { _setActive(value) }
        bool active() { return _getActive() }
        SignalConnection onToggled(callback<void(bool)> action) {
            return SignalConnection(_checkSelf(), action)
        }
    }

    class ScrolledWindow : Widget {
        public:
        ScrolledWindow() { super Widget(7, "", 0, 0) }
        void setChild(Widget child) { _attachChild(child) }
        void remove(Widget child) { _removeChild(child) }
    }

    class Notebook : Widget {
        private:
        Notebook _notebookSelf()
        void _closable(int64 token, int64 child, String title, callback<void()> close)
        void _bordered(int64 token)
        void _scrollable(int64 token, bool enabled)
        public:
        Notebook() { super Widget(9, "", 0, 0) }
        void appendPage(Widget child, String title) {
            _notebookAppend(_widgetToken(), child._widgetToken(), title)
        }
        void appendClosablePage(Widget child, String title, callback<void()> close) {
            _closable(_widgetToken(), child._widgetToken(), title, close)
        }
        // Draws a border around every tab label, as closable pages already do.
        void setBorderedTabs() { _bordered(_widgetToken()) }
        void setScrollable(bool enabled) { _scrollable(_widgetToken(), enabled) }
        int64 currentPage() { return _notebookCurrent(_widgetToken()) }
        void setCurrentPage(int64 page) { _notebookSetCurrent(_widgetToken(), page) }
        int64 pageCount() { return _notebookCount(_widgetToken()) }
        void setPageTitle(int64 page, String title) {
            _notebookTitle(_widgetToken(), page, title)
        }
        void remove(Widget child) { _removeChild(child) }
        SignalConnection onPageChanged(callback<void()> action) {
            return SignalConnection(_notebookSelf(), action)
        }
    }

    class Paned : Widget {
        private:
        void _position(int64 token, int64 position)
        int64 _getPosition(int64 token)
        public:
        Paned() { super Widget(12, "", 0, 0) }
        void append(Widget child) { _attachChild(child) }
        void setPosition(int64 position) { _position(_widgetToken(), position) }
        int64 position() { return _getPosition(_widgetToken()) }
    }

    class Tree : Widget {
        private:
        void _singleClick(int64 token, bool enabled)
        void _setup(int64 token, callback<void(int64)> request, callback<void(int64)> activate)
        void _add(int64 token, int64 parent, int64 id, String label, String icon, bool expandable, String value, int64 data)
        void _clear(int64 token, int64 parent)
        void _expandRow(int64 token, int64 id, bool expanded)
        bool _isExpanded(int64 token, int64 id)
        String _value(int64 token, int64 id)
        int64 _data(int64 token, int64 id)
        int64 _find(int64 token, String value)
        int64 _count(int64 token, int64 parent)
        public:
        Tree(callback<void(int64)> request, callback<void(int64)> activate) {
            super Widget(13, "", 0, 0)
            _setup(_widgetToken(), request, activate)
        }
        void setSingleClickActivate(bool enabled) { _singleClick(_widgetToken(), enabled) }
        void add(int64 parent, int64 id, String label, String icon, bool expandable, String value, int64 data) {
            _add(_widgetToken(), parent, id, label, icon, expandable, value, data)
        }
        void clear(int64 parent) { _clear(_widgetToken(), parent) }
        void setExpanded(int64 id, bool expanded) { _expandRow(_widgetToken(), id, expanded) }
        bool expanded(int64 id) { return _isExpanded(_widgetToken(), id) }
        String value(int64 id) { return _value(_widgetToken(), id) }
        int64 data(int64 id) { return _data(_widgetToken(), id) }
        int64 findValue(String value) { return _find(_widgetToken(), value) }
        int64 childCount(int64 parent) { return _count(_widgetToken(), parent) }
    }

    class DirectoryScan {
        private:
        int64 _token
        int64 _start(int64 owner, String path, bool hidden, callback<void(int64, String)> result)
        int64 _startFiltered(int64 owner, String path, bool hidden, String root, String excludes,
            callback<void(int64, String)> result)
        void _cancel(int64 token)
        void _append(int64 token, int64 tree, int64 parent, int64 firstId, int64 count, String icons)
        public:
        DirectoryScan(Tree owner, String path, bool hidden, callback<void(int64, String)> result) {
            _token = _start(owner._widgetToken(), path, hidden, result)
        }
        DirectoryScan(Tree owner, String path, bool hidden, String root, String excludes,
            callback<void(int64, String)> result) {
            _token = _startFiltered(owner._widgetToken(), path, hidden, root, excludes, result)
        }
        void cancel() { _cancel(_token) }
        void append(Tree owner, int64 parent, int64 firstId, int64 count, String icons) {
            _append(_token, owner._widgetToken(), parent, firstId, count, icons)
        }
    }

    class SourceViewWidget : Widget {
        public:
        SourceViewWidget() { super Widget(8, "", 0, 0) }
        int64 nativeToken() { return _widgetToken() }
    }

    void Application._create(String id) from "cwhip_gtk_application_create"
    Application Application._self() from "cwhip_gtk_self"
    Widget Widget._self() from "cwhip_gtk_self"
    Window Window._windowSelf() from "cwhip_gtk_self"
    TransientWindow TransientWindow._transientSelf() from "cwhip_gtk_self"
    Button Button._buttonSelf() from "cwhip_gtk_self"
    Entry Entry._entrySelf() from "cwhip_gtk_self"
    CheckButton CheckButton._checkSelf() from "cwhip_gtk_self"
    Notebook Notebook._notebookSelf() from "cwhip_gtk_self"
    void Application.initialize() from "cwhip_gtk_initialize"
    String Application.id() from "cwhip_gtk_application_id"
    void Application.run() from "cwhip_gtk_run"
    void Application.quit() from "cwhip_gtk_quit"
    void Application.shutdown() from "cwhip_gtk_shutdown"
    void Application.ready() from "cwhip_gtk_ready"
    int64 Application.post(callback<void()> action) from "cwhip_gtk_post"
    bool Application.cancel(int64 token) from "cwhip_gtk_cancel"
    int64 SignalConnection._activate(Application source, callback<void()> action)
        from "cwhip_gtk_activation_signal"
    int64 SignalConnection._click(Button source, callback<void()> action) from "cwhip_gtk_button_signal"
    int64 SignalConnection._changed(Entry source, callback<void(String)> action) from "cwhip_gtk_entry_signal"
    int64 SignalConnection._close(Window source, callback<bool()> action) from "cwhip_gtk_window_signal"
    int64 SignalConnection._close(TransientWindow source, callback<bool()> action)
        from "cwhip_gtk_window_signal"
    int64 SignalConnection._toggled(CheckButton source, callback<void(bool)> action) from "cwhip_gtk_checkbox_signal"
    int64 SignalConnection._pageChanged(Notebook source, callback<void()> action)
        from "cwhip_gtk_notebook_signal"
    int64 SignalConnection._focusChanged(Window source, callback<void(bool)> action)
        from "cwhip_gtk_window_focus_signal"
    void Grid._attachAt(int64 token, int64 child, int64 column, int64 row, int64 width, int64 height)
        from "cwhip_gtk_grid_attach"
    void ContextMenu._bind(int64 token, int64 owner) from "cwhip_gtk_context_menu_bind"
    void Entry._editable(int64 token, bool editable) from "cwhip_gtk_entry_editable"
    void Notebook._closable(int64 token, int64 child, String title, callback<void()> close)
        from "cwhip_gtk_notebook_closable"
    void Notebook._bordered(int64 token) from "cwhip_gtk_notebook_bordered"
    void Notebook._scrollable(int64 token, bool enabled) from "cwhip_gtk_notebook_scrollable"
    bool Window._bindShortcut(int64 token, String trigger, callback<void()> action)
        from "cwhip_gtk_window_bind_shortcut"
    bool Window._hasShortcut(int64 token, String trigger) from "cwhip_gtk_window_has_shortcut"
    bool Window._maximized(int64 token) from "cwhip_gtk_window_maximized"
    void Window._maximize(int64 token, bool enabled) from "cwhip_gtk_window_maximize"
    bool SignalConnection._disconnect(int64 token) from "cwhip_gtk_connection_disconnect"
    bool SignalConnection._connected(int64 token) from "cwhip_gtk_connected"
    int64 Widget._create(int64 kind, String text, int64 orientation, int64 spacing, callback<void()> root)
        from "cwhip_gtk_widget_create"
    void Widget._dispose(int64 token) from "cwhip_gtk_widget_dispose"
    bool Widget._disposed(int64 token) from "cwhip_gtk_widget_disposed"
    void Widget._visible(int64 token, bool value) from "cwhip_gtk_widget_visible"
    void Widget._sensitive(int64 token, bool value) from "cwhip_gtk_widget_sensitive"
    void Widget._expand(int64 token, bool horizontal, bool value) from "cwhip_gtk_widget_expand"
    void Widget._focus(int64 token) from "cwhip_gtk_widget_focus"
    int64 MenuBar._addMenu(int64 token, String label) from "cwhip_gtk_menu_add"
    int64 MenuBar._addItem(int64 token, int64 menu, String label, callback<void()> action)
        from "cwhip_gtk_menu_item_add"
    void MenuBar._enabled(int64 token, int64 item, bool value) from "cwhip_gtk_menu_item_enabled"
    void MenuBar._activate(int64 token, int64 item) from "cwhip_gtk_menu_item_activate"
    void MenuBar._separator(int64 token, int64 menu) from "cwhip_gtk_menu_separator_add"
    int64 FileDialog._create(int64 parent, bool save, String initialPath, callback<void(String)> result)
        from "cwhip_gtk_file_dialog_create"
    int64 FileDialog._createMultiple(int64 parent, String initialPath, callback<void(String)> path)
        from "cwhip_gtk_file_dialog_create_multiple"
    int64 FileDialog._createFolder(int64 parent, String initialPath, callback<void(String)> result)
        from "cwhip_gtk_file_dialog_create_folder"
    void Paned._position(int64 token, int64 position) from "cwhip_gtk_paned_position"
    int64 Paned._getPosition(int64 token) from "cwhip_gtk_paned_get_position"
    bool Tree._isExpanded(int64 token, int64 id) from "cwhip_gtk_tree_is_expanded"
    int64 DirectoryScan._startFiltered(int64 owner, String path, bool hidden, String root,
        String excludes, callback<void(int64, String)> result) from "cwhip_gtk_directory_start_filtered"
    void Tree._setup(int64 token, callback<void(int64)> request, callback<void(int64)> activate)
        from "cwhip_gtk_tree_setup"
    void Tree._singleClick(int64 token, bool enabled) from "cwhip_gtk_tree_single_click"
    void Tree._add(int64 token, int64 parent, int64 id, String label, String icon, bool expandable, String value, int64 data)
        from "cwhip_gtk_tree_add"
    String Tree._value(int64 token, int64 id) from "cwhip_gtk_tree_value"
    int64 Tree._data(int64 token, int64 id) from "cwhip_gtk_tree_data"
    int64 Tree._find(int64 token, String value) from "cwhip_gtk_tree_find"
    int64 Tree._count(int64 token, int64 parent) from "cwhip_gtk_tree_count"
    void Tree._clear(int64 token, int64 parent) from "cwhip_gtk_tree_clear"
    void Tree._expandRow(int64 token, int64 id, bool expanded) from "cwhip_gtk_tree_expand"
    int64 DirectoryScan._start(int64 owner, String path, bool hidden, callback<void(int64, String)> result)
        from "cwhip_gtk_directory_start"
    void DirectoryScan._cancel(int64 token) from "cwhip_gtk_directory_cancel"
    void DirectoryScan._append(int64 token, int64 tree, int64 parent, int64 firstId, int64 count, String icons)
        from "cwhip_gtk_directory_append"
    void AlertDialog._show(int64 parent, String message, String detail) from "cwhip_gtk_alert_show"
    void FileDialog._cancel(int64 token) from "cwhip_gtk_file_dialog_cancel"
    bool FileDialog._pending(int64 token) from "cwhip_gtk_file_dialog_pending"
    void Widget._textSet(int64 token, String text) from "cwhip_gtk_widget_text_set"
    String Widget._textGet(int64 token) from "cwhip_gtk_widget_text_get"
    void Widget._attach(int64 parent, int64 child) from "cwhip_gtk_widget_attach"
    void Widget._remove(int64 parent, int64 child) from "cwhip_gtk_widget_remove"
    void Widget._windowAction(int64 token, int64 action) from "cwhip_gtk_window_action"
    void Widget._windowSize(int64 token, int64 width, int64 height) from "cwhip_gtk_window_size"
    int64 Widget._windowWidth(int64 token) from "cwhip_gtk_window_width"
    int64 Widget._windowHeight(int64 token) from "cwhip_gtk_window_height"
    void Widget._windowTransientFor(int64 token, int64 parent)
        from "cwhip_gtk_window_transient_for"
    void Widget._layout(int64 token, int64 orientation, int64 spacing) from "cwhip_gtk_box_layout"
    void Widget._activeSet(int64 token, bool value) from "cwhip_gtk_checkbox_set"
    bool Widget._activeGet(int64 token) from "cwhip_gtk_checkbox_get"
    void Widget._notebookAppend(int64 notebook, int64 child, String title)
        from "cwhip_gtk_notebook_append"
    int64 Widget._notebookCurrent(int64 notebook) from "cwhip_gtk_notebook_current"
    void Widget._notebookSetCurrent(int64 notebook, int64 page)
        from "cwhip_gtk_notebook_set_current"
    int64 Widget._notebookCount(int64 notebook) from "cwhip_gtk_notebook_count"
    void Widget._notebookTitle(int64 notebook, int64 page, String title)
        from "cwhip_gtk_notebook_title"
}
