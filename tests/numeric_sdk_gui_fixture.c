#include <gtk/gtk.h>
#include <stdint.h>

static GtkWidget *find_widget(GtkWidget *widget, GType type) {
    if (G_TYPE_CHECK_INSTANCE_TYPE(widget, type)) return widget;
    for (GtkWidget *child = gtk_widget_get_first_child(widget); child;
         child = gtk_widget_get_next_sibling(child)) {
        GtkWidget *result = find_widget(child, type);
        if (result) return result;
    }
    return NULL;
}

int64_t numeric_gui_emit(void *self) {
    (void)self;
    GListModel *windows = gtk_window_get_toplevels();
    GtkWidget *tree = NULL;
    GtkWidget *text = NULL;
    for (guint index = 0; index < g_list_model_get_n_items(windows); ++index) {
        GtkWidget *window = g_list_model_get_item(windows, index);
        tree = find_widget(window, GTK_TYPE_LIST_VIEW);
        text = find_widget(window, GTK_TYPE_TEXT_VIEW);
        g_object_unref(window);
        if (tree && text) break;
    }
    if (!tree || !text) return 0;
    /* Realize list rows so expansion notifications have their normal handlers. */
    const gint64 deadline = g_get_monotonic_time() + 2 * G_TIME_SPAN_SECOND;
    while ((!gtk_widget_get_first_child(tree) || gtk_widget_get_height(text) <= 0) &&
           g_get_monotonic_time() < deadline) {
        g_main_context_iteration(NULL, FALSE);
        g_usleep(1000);
    }
    g_signal_emit_by_name(tree, "activate", 0u);
    GtkTextIter first;
    GdkRectangle rectangle;
    int x, y;
    gtk_text_buffer_get_start_iter(gtk_text_view_get_buffer(GTK_TEXT_VIEW(text)), &first);
    gtk_text_view_get_iter_location(GTK_TEXT_VIEW(text), &first, &rectangle);
    gtk_text_view_buffer_to_window_coords(GTK_TEXT_VIEW(text), GTK_TEXT_WINDOW_WIDGET,
        rectangle.x, rectangle.y + rectangle.height / 2, &x, &y);
    GListModel *controllers = gtk_widget_observe_controllers(text);
    int64_t emitted = 1;
    for (guint index = 0; index < g_list_model_get_n_items(controllers); ++index) {
        GtkEventController *controller = g_list_model_get_item(controllers, index);
        if (GTK_IS_GESTURE_CLICK(controller) &&
            gtk_event_controller_get_propagation_phase(controller) == GTK_PHASE_CAPTURE &&
            gtk_gesture_single_get_button(GTK_GESTURE_SINGLE(controller)) == GDK_BUTTON_PRIMARY) {
            g_signal_emit_by_name(controller, "pressed", 1, (double)x, (double)y);
            emitted |= 2;
        }
        g_object_unref(controller);
    }
    g_object_unref(controllers);
    return emitted;
}
