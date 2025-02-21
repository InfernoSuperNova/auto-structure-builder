Root =
{
    Type = "Control",
    Name = "root",
    Style = "Normal",
    Position = { 0, 0, },
    Size = { 0, 0, },
    Children =
    {
        {
            Type = "Static",
            Name = "MessageBox",
            Style = "Panel",
            Texture = "ui/textures/FE-Panel.dds",
            Control =
            {
                ClipChildren = true,
                Position = { 0, 0,},
                ScriptX = "20",
                ScriptY = "20",
                ScriptW = "ScreenW * 0.6 - 20 - 20",
                ScriptH = "ScreenH - 200",
                Size = { 200, 208, },
                Anchor = 0,
                Children =
                {
                    {
                        Type = "TextButton",
                        Name = "BackButton",
                        Style = "Heading",
                        Text =
                        {
                            Text = "$Back",
                            Control =
                            {
                                Position = { 0, 165, },
                                ScriptX = "ParentMiddleX",
                                Size = { 68.63, 21, },
                                Anchor = 1,
                                TabStop = 1,
                                Children =
                                {
                                    {
                                        Type = "Button",
                                        Name = "MessageBoxButton",
                                        Style = "Heading",
                                        Slave = true,
                                        Static =
                                        {
                                            Texture = "ui-button-short",
                                            Control =
                                            {
                                                Position = { 0, -9, },
                                                ScriptX = "ParentMiddleX",
                                                Size = { 192, 41.25, },
                                                Anchor = 1,
                                                DrawEarly = true,
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                    {
                        Type = "Static",
                        Name = "MessageBoxPanel",
                        Style = "Normal",
                        Texture = "",
                        Colour = { 255, 255, 255, 0 },
                        ColourLower = { 255, 255, 255, 0 },
                        Control =
                        {
                            Position = { 0, 30 },
                            ScriptX = "ParrentMiddleX",
                            Size = { 0, 0, },
                            Anchor = 0,
                            Children =
                            {
                                {
                                    Type = "Text",
                                    Name = "MessageBoxText",
                                    Style = "Normal",
                                    Text = "Select your vehicle:",
                                    Size = 16.000,
                                    Wrap = true,
                                    Control =
                                    {
                                        Position = { 0, 0, },
                                        Size = { 446.62, 83.20, },
                                        Anchor = 8,
                                    },
                                },
                            },
                        },
                    },
                    {
                        Type = "TextButton",
                        Name = "MessageBoxTextButtonRight",
                        Style = "Heading",
                        Text =
                        {
                            Text = "$Next",
                            Control =
                            {
                                Position = { 134.67, 165, },
                                Size = { 50.44, 21, },
                                Anchor = 1,
                                TabStop = 1,
                                Children =
                                {
                                    {
                                        Type = "Button",
                                        Name = "MessageBoxButtonRight",
                                        Style = "Heading",
                                        Slave = true,
                                        Static =
                                        {
                                            Texture = "ui-button-short",
                                            Control =
                                            {
                                                Position = { 0, -9, },
                                                ScriptX = "ParentMiddleX",
                                                Size = { 192, 41.25, },
                                                Anchor = 1,
                                                DrawEarly = true,
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    },
}
