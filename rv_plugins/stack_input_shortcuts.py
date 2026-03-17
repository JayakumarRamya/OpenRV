from rv import rvtypes, commands

class StackInputShortcutsMode(rvtypes.MinorMode):

    def __init__(self):
        rvtypes.MinorMode.__init__(self)
        self.init(
            "stack_input_shortcuts",
            [
                ("key-down--1", self.show_input_1, "Switch to Stack Input 1"),
                ("key-down--2", self.show_input_2, "Switch to Stack Input 2"),
                ("key-down--3", self.show_input_3, "Switch to Stack Input 3"),
            ],
            None
        )

    def get_source_group(self, node_name):
        """Extract actual sourceGroup from retime wrapper node name.
        e.g. defaultLayout_rt_sourceGroup000000 -> sourceGroup000000
             defaultStack_rt_sourceGroup000000  -> sourceGroup000000
             sourceGroup000000                  -> sourceGroup000000
        """
        if "_rt_" in node_name:
            return node_name.split("_rt_")[-1]
        return node_name

    def get_color_node(self, source_group):
        """Find RVColor node inside sourceGroup_colorPipeline."""
        pipeline = "%s_colorPipeline" % source_group
        try:
            pipeline_nodes = commands.nodesInGroup(pipeline)
            for n in pipeline_nodes:
                try:
                    if commands.nodeType(n) == "RVColor":
                        return n
                except:
                    pass
        except Exception as e:
            print("[OpenRV] colorPipeline error: %s" % e)

        # Fallback
        fallback = "%s_color" % source_group
        try:
            commands.nodeType(fallback)
            return fallback
        except:
            pass

        return None

    def get_color_settings(self, source_group):
        """Read all grade settings from source group."""
        settings = {}
        color_node = self.get_color_node(source_group)
        if not color_node:
            return settings

        props = [
            "color.exposure",
            "color.gamma",
            "color.saturation",
            "color.contrast",
            "color.hue",
            "color.offset",
            "color.scale",
        ]

        for prop in props:
            try:
                val = commands.getFloatProperty(
                    "%s.%s" % (color_node, prop)
                )
                if val is not None:
                    settings[prop] = val
            except:
                pass

        return settings

    def apply_color_settings(self, source_group, settings):
        """Apply grade settings to target source group."""
        color_node = self.get_color_node(source_group)
        if not color_node:
            return

        for prop, val in settings.items():
            try:
                commands.setFloatProperty(
                    "%s.%s" % (color_node, prop),
                    val, True
                )
            except Exception as e:
                print("[OpenRV] Failed %s: %s" % (prop, e))

    def reset_transform(self, source_group, stack_node):
        """Reset spatial transform so input shows full centered view."""
        try:
            # ✅ Reset transform inside the stack for this source
            # Stack transform node is named: <stack>_t_<sourceGroup>
            stack_base = stack_node.replace("_stack", "").replace("Stack", "")
            transform_node = "%s_t_%s" % (stack_base, source_group)
            try:
                commands.nodeType(transform_node)
                commands.setFloatProperty(
                    "%s.transform.translate" % transform_node,
                    [0.0, 0.0], True
                )
                commands.setFloatProperty(
                    "%s.transform.scale" % transform_node,
                    [1.0], True
                )
                print("[OpenRV] Reset transform: %s" % transform_node)
            except:
                pass

            # ✅ Also reset the source's own transform
            src_transform = "%s_transform2D" % source_group
            try:
                commands.nodeType(src_transform)
                commands.setFloatProperty(
                    "%s.transform.translate" % src_transform,
                    [0.0, 0.0], True
                )
                commands.setFloatProperty(
                    "%s.transform.scale" % src_transform,
                    [1.0], True
                )
                print("[OpenRV] Reset source transform: %s" % src_transform)
            except:
                pass

        except Exception as e:
            print("[OpenRV] Transform reset error: %s" % e)

        # ✅ Reset viewer pan and zoom
        try:
            commands.setTranslation((0.0, 0.0))
            commands.setScale(1.0)
        except:
            pass

        # ✅ Fit image to window
        try:
            commands.frameImage()
        except:
            pass

    def switch_to_input(self, index):
        view = commands.viewNode()
        if not view:
            return

        # ✅ Save current frame
        current_frame = commands.frame()

        # ✅ Get actual sourceGroup from current view
        current_source = self.get_source_group(view)

        # ✅ Save color settings
        current_color = self.get_color_settings(current_source)

        # ✅ Find stack node
        stack_node = None
        node_type = commands.nodeType(view)

        if "Stack" in node_type:
            stack_node = view
        else:
            nodes = commands.nodesOfType("RVStack")
            if nodes:
                stack_node = nodes[0]

        if stack_node is None:
            print("[OpenRV] No stack node found")
            return

        inputs = commands.nodeConnections(stack_node, False)[0]

        if index < len(inputs):
            target_input  = inputs[index]
            target_source = self.get_source_group(target_input)

            # ✅ Switch view
            commands.setViewNode(target_input)

            # ✅ Restore frame
            commands.setFrame(current_frame)

            # ✅ Reset spatial transform — fixes left/right/center offset
            self.reset_transform(target_source, stack_node)

            # ✅ Apply color settings
            if current_color:
                self.apply_color_settings(target_source, current_color)

            try:
                commands.redraw()
            except:
                pass

    def show_input_1(self, event):
        self.switch_to_input(0)

    def show_input_2(self, event):
        self.switch_to_input(1)

    def show_input_3(self, event):
        self.switch_to_input(2)


def createMode():
    return StackInputShortcutsMode()
