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
        void save(String path, String text, String expected, void<String> result)
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
    void Config.save(String path, String text, String expected, void<String> result)
        from "cwhip_gtk_config_save"
    String Config.saveNow(String path, String text, String expected) from "cwhip_gtk_config_save_now"

    class Keyboard {
        String normalize(String trigger)
        int64 record(Entry entry, void<String> result)
        bool cancel(int64 token)
    }
    String Keyboard.normalize(String trigger) from "cwhip_gtk_keyboard_normalize"
    int64 Keyboard.record(Entry entry, void<String> result) from "cwhip_gtk_keyboard_record"
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
        SignalConnection onActivate(void<> action) {
            return(SignalConnection(_self(), action))
        }
        void run()
        void quit()
        void shutdown()
        int64 post(void<> action)
        int64 schedule(int64 milliseconds, void<> action)
        bool cancel(int64 token)
    }

    class SignalConnection {
        private:
        int64 _token
        int64 _activate(Application source, void<> action)
        int64 _click(Button source, void<> action)
        int64 _changed(Entry source, void<String> action)
        int64 _close(Window source, bool<> action)
        int64 _close(TransientWindow source, bool<> action)
        int64 _toggled(CheckButton source, void<bool> action)
        int64 _pageChanged(Notebook source, void<> action)
        int64 _focusChanged(Window source, void<bool> action)
        bool _disconnect(int64 token)
        bool _connected(int64 token)
        public:
        SignalConnection(Application source, void<> action) {
            _token = _activate(source, action)
        }
        SignalConnection(Button source, void<> action) {
            _token = _click(source, action)
        }
        SignalConnection(Entry source, void<String> action) {
            _token = _changed(source, action)
        }
        SignalConnection(Window source, bool<> action) {
            _token = _close(source, action)
        }
        SignalConnection(TransientWindow source, bool<> action) {
            _token = _close(source, action)
        }
        SignalConnection(CheckButton source, void<bool> action) {
            _token = _toggled(source, action)
        }
        SignalConnection(Notebook source, void<> action) {
            _token = _pageChanged(source, action)
        }
        SignalConnection(Window source, void<bool> action) {
            _token = _focusChanged(source, action)
        }
        bool disconnect() { return(_disconnect(_token))}
        bool connected() { return(_connected(_token))}
    }

    class Widget {
        private:
        int64 _id
        Widget _self()
        void _keepAlive() {}
        int64 _create(int64 kind, String text, int64 orientation, int64 spacing, void<> root)
        void _dispose(int64 token)
        bool _disposed(int64 token)
        void _visible(int64 token, bool value)
        bool _isVisible(int64 token)
        void _sensitive(int64 token, bool value)
        void _expand(int64 token, bool horizontal, bool value)
        void _widthRequest(int64 token, int64 width)
        void _cssClass(int64 token, String name, bool add)
        void _tooltip(int64 token, String text)
        void _focus(int64 token)
        void _focusOnClick(int64 token, bool enabled)
        void _canFocus(int64 token, bool enabled)
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
        String _getText() { return(_textGet(_id))}
        void _attachChild(Widget child) { _attach(_id, child._id) }
        void _removeChild(Widget child) { _remove(_id, child._id) }
        void _presentWindow() { _windowAction(_id, 0) }
        void _closeWindow() { _windowAction(_id, 1) }
        void _sizeWindow(int64 width, int64 height) { _windowSize(_id, width, height) }
        int64 _defaultWidth() { return(_windowWidth(_id))}
        int64 _defaultHeight() { return(_windowHeight(_id))}
        void _setTransientFor(int64 parent) { _windowTransientFor(_id, parent) }
        void _boxLayout(int64 orientation, int64 spacing) { _layout(_id, orientation, spacing) }
        void _setActive(bool value) { _activeSet(_id, value) }
        bool _getActive() { return(_activeGet(_id))}
        void _grabFocus() { _focus(_id) }
        public:
        int64 _widgetToken() { return(_id)}
        void dispose() { _dispose(_id) }
        bool disposed() { return(_disposed(_id))}
        void setVisible(bool value) { _visible(_id, value) }
        bool visible() { return(_isVisible(_id)) }
        void setSensitive(bool value) { _sensitive(_id, value) }
        void setHExpand(bool value) { _expand(_id, true, value) }
        void setVExpand(bool value) { _expand(_id, false, value) }
        void setWidthRequest(int64 width) { _widthRequest(_id, width) }
        void addCssClass(String name) { _cssClass(_id, name, true) }
        void removeCssClass(String name) { _cssClass(_id, name, false) }
        void setTooltip(String text) { _tooltip(_id, text) }
        // Buttons default to focus-on-click off; use these for toolbar controls
        // that must not take focus from an editor on the first press.
        void setFocusOnClick(bool enabled) { _focusOnClick(_id, enabled) }
        void setCanFocus(bool enabled) { _canFocus(_id, enabled) }
    }

    class Window : Widget {
        private:
        Window _windowSelf()
        bool _bindShortcut(int64 token, String trigger, void<> action)
        bool _hasShortcut(int64 token, String trigger)
        bool _maximized(int64 token)
        void _maximize(int64 token, bool enabled)
        void _setMenubarAccel(int64 token, bool enabled)
        bool _menubarAccel(int64 token)
        public:
        Window(String title) { super Widget(1, title, 0, 0) }
        void setTitle(String title) { _setText(title) }
        String title() { return(_getText())}
        void setDefaultSize(int64 width, int64 height) { _sizeWindow(width, height) }
        int64 defaultWidth() { return(_defaultWidth())}
        int64 defaultHeight() { return(_defaultHeight())}
        bool maximized() { return(_maximized(_widgetToken()))}
        void setMaximized(bool enabled) { _maximize(_widgetToken(), enabled) }
        // GTK defaults to consuming F10 for the menubar; set false when F10 is
        // an application shortcut (bindShortcut("F10", ...) also clears it).
        void setMenubarAccel(bool enabled) { _setMenubarAccel(_widgetToken(), enabled) }
        bool menubarAccel() { return(_menubarAccel(_widgetToken()))}
        void setTransientFor(Window parent) {
            _setTransientFor(parent._widgetToken())
        }
        void setChild(Widget child) { _attachChild(child) }
        void remove(Widget child) { _removeChild(child) }
        void present() { _presentWindow() }
        void close() { _closeWindow() }
        // Binds a GTK accelerator such as "<Control>q" for the whole window.
        bool bindShortcut(String trigger, void<> action) {
            return(_bindShortcut(_widgetToken(), trigger, action))
        }
        bool hasShortcut(String trigger) { return(_hasShortcut(_widgetToken(), trigger))}
        SignalConnection onCloseRequest(bool<> action) {
            return(SignalConnection(_windowSelf(), action))
        }
        SignalConnection onFocusChanged(void<bool> action) {
            return(SignalConnection(_windowSelf(), action))
        }
    }

    class TransientWindow : Widget {
        private:
        TransientWindow _transientSelf()
        public:
        TransientWindow(String title) { super Widget(11, title, 0, 0) }
        void setTitle(String title) { _setText(title) }
        String title() { return(_getText())}
        void setDefaultSize(int64 width, int64 height) { _sizeWindow(width, height) }
        void setTransientFor(Window parent) {
            _setTransientFor(parent._widgetToken())
        }
        void setChild(Widget child) { _attachChild(child) }
        void remove(Widget child) { _removeChild(child) }
        void present() { _presentWindow() }
        void close() { _closeWindow() }
        SignalConnection onCloseRequest(bool<> action) {
            return(SignalConnection(_transientSelf(), action))
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
        String text() { return(_getText())}
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
        int64 _addItem(int64 token, int64 menu, String label, void<> action)
        int64 _addCheck(int64 token, int64 menu, String label, bool initial, void<bool> action)
        void _enabled(int64 token, int64 item, bool value)
        void _checked(int64 token, int64 item, bool value)
        bool _isChecked(int64 token, int64 item)
        public:
        ContextMenu(Widget owner) {
            super Widget(15, "", 0, 0)
            _bind(_widgetToken(), owner._widgetToken())
        }
        // Prefer addItem/addCheckItem so the menu looks like a native popup.
        // setChild still accepts a custom widget for callers that need one.
        void setChild(Widget child) { _attachChild(child) }
        int64 addItem(String label, void<> action) {
            return(_addItem(_widgetToken(), 0, label, action))
        }
        int64 addCheckItem(String label, bool initial, void<bool> action) {
            return(_addCheck(_widgetToken(), 0, label, initial, action))
        }
        void setItemEnabled(int64 item, bool enabled) { _enabled(_widgetToken(), item, enabled) }
        void setItemChecked(int64 item, bool checked) { _checked(_widgetToken(), item, checked) }
        bool itemChecked(int64 item) { return(_isChecked(_widgetToken(), item)) }
    }

    class Button : Widget {
        private:
        Button _buttonSelf()
        void _icon(int64 token, String name)
        public:
        Button(String label) { super Widget(4, label, 0, 0) }
        void setLabel(String label) { _setText(label) }
        String label() { return(_getText())}
        void setIconName(String name) { _icon(_widgetToken(), name) }
        SignalConnection onClicked(void<> action) {
            return(SignalConnection(_buttonSelf(), action))
        }
    }

    class Entry : Widget {
        private:
        Entry _entrySelf()
        void _editable(int64 token, bool editable)
        public:
        Entry(String text) { super Widget(5, text, 0, 0) }
        void setText(String text) { _setText(text) }
        String text() { return(_getText())}
        SignalConnection onChanged(void<String> action) {
            return(SignalConnection(_entrySelf(), action))
        }
        void focus() { _grabFocus() }
        void setEditable(bool editable) { _editable(_widgetToken(), editable) }
    }

    class MenuBar : Widget {
        private:
        int64 _addMenu(int64 token, String label)
        int64 _addItem(int64 token, int64 menu, String label, void<> action)
        void _enabled(int64 token, int64 item, bool value)
        void _activate(int64 token, int64 item)
        void _separator(int64 token, int64 menu)
        int64 _addCheck(int64 token, int64 menu, String label, bool initial, void<bool> action)
        int64 _addSubmenu(int64 token, int64 menu, String label)
        void _clearMenu(int64 token, int64 menu)
        void _checked(int64 token, int64 item, bool value)
        bool _isChecked(int64 token, int64 item)
        public:
        MenuBar() { super Widget(10, "", 0, 0) }
        int64 addMenu(String label) { return(_addMenu(_widgetToken(), label))}
        int64 addItem(int64 menu, String label, void<> action) {
            return(_addItem(_widgetToken(), menu, label, action))
        }
        // Draws a divider before the next item added to menu.
        void addSeparator(int64 menu) { _separator(_widgetToken(), menu) }
        int64 addCheckItem(int64 menu, String label, bool initial, void<bool> action) {
            return(_addCheck(_widgetToken(), menu, label, initial, action))
        }
        int64 addSubmenu(int64 menu, String label) {
            return(_addSubmenu(_widgetToken(), menu, label))
        }
        void clearMenu(int64 menu) { _clearMenu(_widgetToken(), menu) }
        void setItemEnabled(int64 item, bool enabled) { _enabled(_widgetToken(), item, enabled) }
        void activateItem(int64 item) { _activate(_widgetToken(), item) }
        void setItemChecked(int64 item, bool checked) { _checked(_widgetToken(), item, checked) }
        bool itemChecked(int64 item) { return(_isChecked(_widgetToken(), item)) }
    }

    class FileSelection {
        private:
        list _paths
        void<list> _result
        public:
        FileSelection(void<list> result) {
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
        int64 _create(int64 parent, bool save, String initialPath, void<String> result)
        int64 _createMultiple(int64 parent, String initialPath, void<String> path)
        int64 _createFolder(int64 parent, String initialPath, void<String> result)
        void _cancel(int64 token)
        bool _pending(int64 token)
        public:
        FileDialog(Window parent, bool save, String initialPath, void<String> result) {
            _token = _create(parent._widgetToken(), save, initialPath, result)
        }
        FileDialog(Window parent, String initialPath, void<list> results) {
            _selection = FileSelection(results)
            _token = _createMultiple(parent._widgetToken(), initialPath, _selection.add)
        }
        FileDialog(Window parent, String initialPath, void<String> folder) {
            _token = _createFolder(parent._widgetToken(), initialPath, folder)
        }
        void cancel() { _cancel(_token) }
        bool pending() { return(_pending(_token))}
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
        String label() { return(_getText())}
        void setActive(bool value) { _setActive(value) }
        bool active() { return(_getActive())}
        SignalConnection onToggled(void<bool> action) {
            return(SignalConnection(_checkSelf(), action))
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
        void _closable(int64 token, int64 child, String title, void<> close)
        void _bordered(int64 token)
        void _scrollable(int64 token, bool enabled)
        public:
        Notebook() { super Widget(9, "", 0, 0) }
        void appendPage(Widget child, String title) {
            _notebookAppend(_widgetToken(), child._widgetToken(), title)
        }
        void appendClosablePage(Widget child, String title, void<> close) {
            _closable(_widgetToken(), child._widgetToken(), title, close)
        }
        // Draws a border around every tab label, as closable pages already do.
        void setBorderedTabs() { _bordered(_widgetToken()) }
        void setScrollable(bool enabled) { _scrollable(_widgetToken(), enabled) }
        int64 currentPage() { return(_notebookCurrent(_widgetToken()))}
        void setCurrentPage(int64 page) { _notebookSetCurrent(_widgetToken(), page) }
        int64 pageCount() { return(_notebookCount(_widgetToken()))}
        void setPageTitle(int64 page, String title) {
            _notebookTitle(_widgetToken(), page, title)
        }
        void remove(Widget child) { _removeChild(child) }
        SignalConnection onPageChanged(void<> action) {
            return(SignalConnection(_notebookSelf(), action))
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
        int64 position() { return(_getPosition(_widgetToken()))}
    }

    class Tree : Widget {
        private:
        void _singleClick(int64 token, bool enabled)
        void _setup(int64 token, void<int64> request, void<int64> activate)
        void _add(int64 token, int64 parent, int64 id, String label, String icon, bool expandable, String value, int64 data)
        void _clear(int64 token, int64 parent)
        void _expandRow(int64 token, int64 id, bool expanded)
        bool _isExpanded(int64 token, int64 id)
        String _value(int64 token, int64 id)
        int64 _data(int64 token, int64 id)
        int64 _find(int64 token, String value)
        int64 _count(int64 token, int64 parent)
        public:
        Tree(void<int64> request, void<int64> activate) {
            super Widget(13, "", 0, 0)
            _setup(_widgetToken(), request, activate)
        }
        void setSingleClickActivate(bool enabled) { _singleClick(_widgetToken(), enabled) }
        void add(int64 parent, int64 id, String label, String icon, bool expandable, String value, int64 data) {
            _add(_widgetToken(), parent, id, label, icon, expandable, value, data)
        }
        void clear(int64 parent) { _clear(_widgetToken(), parent) }
        void setExpanded(int64 id, bool expanded) { _expandRow(_widgetToken(), id, expanded) }
        bool expanded(int64 id) { return(_isExpanded(_widgetToken(), id))}
        String value(int64 id) { return(_value(_widgetToken(), id))}
        int64 data(int64 id) { return(_data(_widgetToken(), id))}
        int64 findValue(String value) { return(_find(_widgetToken(), value))}
        int64 childCount(int64 parent) { return(_count(_widgetToken(), parent))}
    }

    class DirectoryScan {
        private:
        int64 _token
        int64 _start(int64 owner, String path, bool hidden, void<int64, String> result)
        int64 _startFiltered(int64 owner, String path, bool hidden, String root, String excludes,
            void<int64, String> result)
        void _cancel(int64 token)
        void _append(int64 token, int64 tree, int64 parent, int64 firstId, int64 count, String icons)
        public:
        DirectoryScan(Tree owner, String path, bool hidden, void<int64, String> result) {
            _token = _start(owner._widgetToken(), path, hidden, result)
        }
        DirectoryScan(Tree owner, String path, bool hidden, String root, String excludes,
            void<int64, String> result) {
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
        int64 nativeToken() { return(_widgetToken())}
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
    int64 Application.post(void<> action) from "cwhip_gtk_post"
    int64 Application.schedule(int64 milliseconds, void<> action) from "cwhip_gtk_schedule"
    bool Application.cancel(int64 token) from "cwhip_gtk_cancel"
    int64 SignalConnection._activate(Application source, void<> action)
        from "cwhip_gtk_activation_signal"
    int64 SignalConnection._click(Button source, void<> action) from "cwhip_gtk_button_signal"
    int64 SignalConnection._changed(Entry source, void<String> action) from "cwhip_gtk_entry_signal"
    int64 SignalConnection._close(Window source, bool<> action) from "cwhip_gtk_window_signal"
    int64 SignalConnection._close(TransientWindow source, bool<> action)
        from "cwhip_gtk_window_signal"
    int64 SignalConnection._toggled(CheckButton source, void<bool> action) from "cwhip_gtk_checkbox_signal"
    int64 SignalConnection._pageChanged(Notebook source, void<> action)
        from "cwhip_gtk_notebook_signal"
    int64 SignalConnection._focusChanged(Window source, void<bool> action)
        from "cwhip_gtk_window_focus_signal"
    void Grid._attachAt(int64 token, int64 child, int64 column, int64 row, int64 width, int64 height)
        from "cwhip_gtk_grid_attach"
    void ContextMenu._bind(int64 token, int64 owner) from "cwhip_gtk_context_menu_bind"
    int64 ContextMenu._addItem(int64 token, int64 menu, String label, void<> action)
        from "cwhip_gtk_menu_item_add"
    int64 ContextMenu._addCheck(int64 token, int64 menu, String label, bool initial, void<bool> action)
        from "cwhip_gtk_menu_check_add"
    void ContextMenu._enabled(int64 token, int64 item, bool value) from "cwhip_gtk_menu_item_enabled"
    void ContextMenu._checked(int64 token, int64 item, bool value) from "cwhip_gtk_menu_item_set_checked"
    bool ContextMenu._isChecked(int64 token, int64 item) from "cwhip_gtk_menu_item_checked"
    void Entry._editable(int64 token, bool editable) from "cwhip_gtk_entry_editable"
    void Notebook._closable(int64 token, int64 child, String title, void<> close)
        from "cwhip_gtk_notebook_closable"
    void Notebook._bordered(int64 token) from "cwhip_gtk_notebook_bordered"
    void Notebook._scrollable(int64 token, bool enabled) from "cwhip_gtk_notebook_scrollable"
    bool Window._bindShortcut(int64 token, String trigger, void<> action)
        from "cwhip_gtk_window_bind_shortcut"
    bool Window._hasShortcut(int64 token, String trigger) from "cwhip_gtk_window_has_shortcut"
    bool Window._maximized(int64 token) from "cwhip_gtk_window_maximized"
    void Window._maximize(int64 token, bool enabled) from "cwhip_gtk_window_maximize"
    void Window._setMenubarAccel(int64 token, bool enabled)
        from "cwhip_gtk_window_handle_menubar_accel"
    bool Window._menubarAccel(int64 token)
        from "cwhip_gtk_window_handles_menubar_accel"
    bool SignalConnection._disconnect(int64 token) from "cwhip_gtk_connection_disconnect"
    bool SignalConnection._connected(int64 token) from "cwhip_gtk_connected"
    int64 Widget._create(int64 kind, String text, int64 orientation, int64 spacing, void<> root)
        from "cwhip_gtk_widget_create"
    void Widget._dispose(int64 token) from "cwhip_gtk_widget_dispose"
    bool Widget._disposed(int64 token) from "cwhip_gtk_widget_disposed"
    void Widget._visible(int64 token, bool value) from "cwhip_gtk_widget_visible"
    bool Widget._isVisible(int64 token) from "cwhip_gtk_widget_is_visible"
    void Widget._sensitive(int64 token, bool value) from "cwhip_gtk_widget_sensitive"
    void Widget._focusOnClick(int64 token, bool enabled) from "cwhip_gtk_widget_focus_on_click"
    void Widget._canFocus(int64 token, bool enabled) from "cwhip_gtk_widget_can_focus"
    void Widget._expand(int64 token, bool horizontal, bool value) from "cwhip_gtk_widget_expand"
    void Widget._widthRequest(int64 token, int64 width) from "cwhip_gtk_widget_width_request"
    void Widget._cssClass(int64 token, String name, bool add) from "cwhip_gtk_widget_css_class"
    void Widget._tooltip(int64 token, String text) from "cwhip_gtk_widget_tooltip"
    void Widget._focus(int64 token) from "cwhip_gtk_widget_focus"
    void Button._icon(int64 token, String name) from "cwhip_gtk_button_icon"
    int64 MenuBar._addMenu(int64 token, String label) from "cwhip_gtk_menu_add"
    int64 MenuBar._addItem(int64 token, int64 menu, String label, void<> action)
        from "cwhip_gtk_menu_item_add"
    void MenuBar._enabled(int64 token, int64 item, bool value) from "cwhip_gtk_menu_item_enabled"
    void MenuBar._activate(int64 token, int64 item) from "cwhip_gtk_menu_item_activate"
    void MenuBar._separator(int64 token, int64 menu) from "cwhip_gtk_menu_separator_add"
    int64 MenuBar._addCheck(int64 token, int64 menu, String label, bool initial, void<bool> action)
        from "cwhip_gtk_menu_check_add"
    void MenuBar._checked(int64 token, int64 item, bool value) from "cwhip_gtk_menu_item_set_checked"
    bool MenuBar._isChecked(int64 token, int64 item) from "cwhip_gtk_menu_item_checked"
    int64 MenuBar._addSubmenu(int64 token, int64 menu, String label) from "cwhip_gtk_menu_submenu_add"
    void MenuBar._clearMenu(int64 token, int64 menu) from "cwhip_gtk_menu_clear"
    int64 FileDialog._create(int64 parent, bool save, String initialPath, void<String> result)
        from "cwhip_gtk_file_dialog_create"
    int64 FileDialog._createMultiple(int64 parent, String initialPath, void<String> path)
        from "cwhip_gtk_file_dialog_create_multiple"
    int64 FileDialog._createFolder(int64 parent, String initialPath, void<String> result)
        from "cwhip_gtk_file_dialog_create_folder"
    void Paned._position(int64 token, int64 position) from "cwhip_gtk_paned_position"
    int64 Paned._getPosition(int64 token) from "cwhip_gtk_paned_get_position"
    bool Tree._isExpanded(int64 token, int64 id) from "cwhip_gtk_tree_is_expanded"
    int64 DirectoryScan._startFiltered(int64 owner, String path, bool hidden, String root,
        String excludes, void<int64, String> result) from "cwhip_gtk_directory_start_filtered"
    void Tree._setup(int64 token, void<int64> request, void<int64> activate)
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
    int64 DirectoryScan._start(int64 owner, String path, bool hidden, void<int64, String> result)
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
