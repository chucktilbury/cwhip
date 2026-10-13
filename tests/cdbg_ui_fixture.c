#include <cwhip/Stdlib.h>
#include <gtk/gtk.h>
#include <gtksourceview/gtksource.h>
#include <math.h>
#include <string.h>

static GtkWindow *debugger_window(void) {
    GList *windows = gtk_application_get_windows(
        GTK_APPLICATION(g_application_get_default()));
    for (GList *item = windows; item; item = item->next)
        if (g_strcmp0(gtk_window_get_title(item->data), "cdbg - local GDB prototype") == 0)
            return item->data;
    return NULL;
}

static GtkWidget *find_type(GtkWidget *widget, GType type) {
    if (G_TYPE_CHECK_INSTANCE_TYPE(widget, type)) return widget;
    for (GtkWidget *child = gtk_widget_get_first_child(widget); child;
         child = gtk_widget_get_next_sibling(child)) {
        GtkWidget *found = find_type(child, type);
        if (found) return found;
    }
    return NULL;
}

static GtkTextView *source_view(void) {
    GtkWindow *window = debugger_window();
    GtkWidget *notebook = window ? find_type(GTK_WIDGET(window), GTK_TYPE_NOTEBOOK) : NULL;
    if (!notebook) return NULL;
    GtkWidget *page = gtk_notebook_get_nth_page(GTK_NOTEBOOK(notebook),
        gtk_notebook_get_current_page(GTK_NOTEBOOK(notebook)));
    return page ? GTK_TEXT_VIEW(find_type(page, GTK_TYPE_TEXT_VIEW)) : NULL;
}

static void label_text(GtkWidget *widget, GString *text) {
    if (GTK_IS_LABEL(widget)) g_string_append(text, gtk_label_get_text(GTK_LABEL(widget)));
    for (GtkWidget *child = gtk_widget_get_first_child(widget); child;
         child = gtk_widget_get_next_sibling(child))
        label_text(child, text);
}

bool cdbg_fixture_alert(void *self) {
    (void)self;
    GtkWindow *parent = debugger_window();
    GListModel *windows = gtk_window_get_toplevels();
    bool found = false;
    for (guint i = 0; i < g_list_model_get_n_items(windows); ++i) {
        GtkWindow *window = g_list_model_get_item(windows, i);
        if (window != parent && gtk_window_get_transient_for(window) == parent &&
            gtk_widget_get_visible(GTK_WIDGET(window)) && gtk_window_get_modal(window)) {
            GString *text = g_string_new(NULL);
            label_text(GTK_WIDGET(window), text);
            found = strstr(text->str, "Could not load file") != NULL;
            g_string_free(text, TRUE);
            if (found) {
                GtkWidget *button = find_type(GTK_WIDGET(window), GTK_TYPE_BUTTON);
                if (button) g_signal_emit_by_name(button, "clicked");
            }
        }
        g_object_unref(window);
        if (found) break;
    }
    return found;
}

static bool panes_readonly(GtkWidget *widget) {
    if (GTK_IS_TEXT_VIEW(widget) &&
        (gtk_text_view_get_editable(GTK_TEXT_VIEW(widget)) ||
         !(gtk_text_view_get_input_hints(GTK_TEXT_VIEW(widget)) & GTK_INPUT_HINT_NO_EMOJI)))
        return false;
    for (GtkWidget *child = gtk_widget_get_first_child(widget); child;
         child = gtk_widget_get_next_sibling(child))
        if (!panes_readonly(child)) return false;
    return true;
}

bool cdbg_fixture_panes(void *self) {
    (void)self;
    GtkWindow *window = debugger_window();
    return window && panes_readonly(GTK_WIDGET(window));
}

bool cdbg_fixture_no_emoji(void *self) {
    (void)self;
    GtkTextView *view = source_view();
    if (!view || !gtk_widget_activate_action(GTK_WIDGET(view), "menu.popup", NULL))
        return false;
    GtkWidget *menu = find_type(GTK_WIDGET(view), GTK_TYPE_POPOVER_MENU);
    GString *text = g_string_new(NULL);
    if (menu) label_text(menu, text);
    bool valid = menu && !strstr(text->str, "Emoji") && strstr(text->str, "Copy");
    if (menu) gtk_popover_popdown(GTK_POPOVER(menu));
    g_string_free(text, TRUE);
    return valid;
}

bool cdbg_fixture_centered(void *self) {
    (void)self;
    GtkTextView *view = source_view();
    if (!view || !gtk_widget_get_mapped(GTK_WIDGET(view))) return false;
    GtkTextBuffer *buffer = gtk_text_view_get_buffer(view);
    GtkTextIter cursor;
    gtk_text_buffer_get_iter_at_mark(buffer, &cursor, gtk_text_buffer_get_insert(buffer));
    GdkRectangle line, visible;
    gtk_text_view_get_iter_location(view, &cursor, &line);
    gtk_text_view_get_visible_rect(view, &visible);
    double delta = fabs(line.y + line.height / 2.0 - visible.y - visible.height / 2.0);
    return visible.height > 100 && delta <= 2 * line.height;
}

static int64_t buffer_changes;

static void changed(GtkTextBuffer *buffer, gpointer unused) {
    (void)buffer;
    (void)unused;
    ++buffer_changes;
}

void cdbg_fixture_track(void *self) {
    (void)self;
    GtkTextView *view = source_view();
    if (!view) g_error("Missing source view");
    GtkTextBuffer *buffer = gtk_text_view_get_buffer(view);
    g_signal_connect(buffer, "changed", G_CALLBACK(changed), NULL);
    buffer_changes = 0;
}

int64_t cdbg_fixture_changes(void *self) {
    (void)self;
    return buffer_changes;
}
