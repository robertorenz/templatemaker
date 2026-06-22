using System.Linq;
using ClarionTplDesigner;
using Xunit;

namespace ClarionTplDesigner.Tests;

// Characterization tests for #INSERT(%group) resolution (TplParser.InlineGroup / HandleElement).
// A #INSERT(%group) inside a #SHEET inlines the prompts a #GROUP(%group) declares: the inlined
// controls are marked Foreign (read-only — never re-emitted on save) and AnchorLine'd back to the
// host #INSERT line for source navigation. Unknown groups are ignored; self-insertion can't loop.
public class TplInsertTests
{
    // A #GROUP(%shared) of two prompts, inserted into the General tab ahead of one native prompt.
    const string Sample = """
        #TEMPLATE(t,'t'),FAMILY('ABC')
        #GROUP(%shared)
          #PROMPT('&Shared:',@s30),%xShared,AT(10)
          #DISPLAY('Group note')
        #EXTENSION(myX,'my X'),PROCEDURE
        #SHEET
          #TAB('&General')
            #INSERT(%shared)
            #PROMPT('&Local:',@s30),%xLocal,AT(20)
          #ENDTAB
        #ENDSHEET
        """;

    static TplDocument Parse(string text) => TplParser.ParseText(text, "x.tpl");
    static TplComponent Sheet(TplDocument doc) => doc.Components.First(c => c.HasSheet);

    [Fact]
    public void Insert_InlinesTheGroupsPromptsIntoTheHostTab()
    {
        var tab = Sheet(Parse(Sample)).Tabs[0];

        // The #GROUP(%shared) body (a prompt + a display) is pasted in, plus the native #PROMPT.
        Assert.Equal(3, tab.Children.Count);
        Assert.Equal("%xShared", tab.Children[0].Symbol);   // inlined, ahead of the native prompt
        Assert.Equal(TplKind.Display, tab.Children[1].Kind); // the group's #DISPLAY('Group note')
        Assert.Equal("%xLocal", tab.Children[2].Symbol);     // the host tab's own prompt

        // The inlined prompt is fully parsed (type/AT read from the group line), not just a placeholder.
        Assert.Equal("@s30", tab.Children[0].PromptType);
        Assert.True(tab.Children[0].HasX);
        Assert.Equal(10, tab.Children[0].X);
    }

    [Fact]
    public void Insert_MarksInlinedContentForeign_AndLeavesNativeContentNative()
    {
        var tab = Sheet(Parse(Sample)).Tabs[0];
        var shared = tab.Children.First(e => e.Symbol == "%xShared");
        var note   = tab.Children.First(e => e.Kind == TplKind.Display);
        var local  = tab.Children.First(e => e.Symbol == "%xLocal");

        // Inlined #GROUP content is read-only (never rewritten/re-emitted on save).
        Assert.True(shared.Foreign);
        Assert.True(note.Foreign);

        // The tab's own prompt is normal, editable source.
        Assert.False(local.Foreign);
        Assert.Equal(-1, local.AnchorLine);
    }

    [Fact]
    public void Insert_AnchorsInlinedContentToTheHostInsertLine()
    {
        var doc = Parse(Sample);
        var shared = Sheet(doc).Tabs[0].Children.First(e => e.Symbol == "%xShared");

        // AnchorLine is the host #INSERT line (so the source view can navigate there); in a single-file
        // preview the inlined content's source file is the only file (index 0).
        Assert.True(shared.AnchorLine >= 0);
        Assert.Contains("#INSERT(%shared)", doc.Files[0].Lines[shared.AnchorLine]);
        Assert.Equal(0, shared.SrcFileIndex);
    }

    [Fact]
    public void Insert_OfAnUnknownGroup_LeavesTheTabUntouched()
    {
        const string src = """
            #EXTENSION(myX,'my X'),PROCEDURE
            #SHEET
              #TAB('&General')
                #INSERT(%missing)
                #PROMPT('&Local:',@s30),%xLocal,AT(20)
              #ENDTAB
            #ENDSHEET
            """;
        var tab = Sheet(Parse(src)).Tabs[0];

        // A group we can't see resolves to nothing — no crash, no foreign children, the native prompt stays.
        Assert.Single(tab.Children);
        Assert.Equal("%xLocal", tab.Children[0].Symbol);
        Assert.DoesNotContain(tab.Children, e => e.Foreign);
    }

    [Fact]
    public void Insert_OfASelfReferencingGroup_DoesNotRecurseForever()
    {
        // The group inserts itself — the recursion guard must break the cycle after one pass.
        const string src = """
            #GROUP(%loop)
              #PROMPT('&Once:',@s30),%xOnce,AT(10)
              #INSERT(%loop)
            #EXTENSION(myX,'my X'),PROCEDURE
            #SHEET
              #TAB('&General')
                #INSERT(%loop)
              #ENDTAB
            #ENDSHEET
            """;
        var tab = Sheet(Parse(src)).Tabs[0];

        // One inlined prompt, then the nested self-insert is suppressed (no duplicate, no hang).
        Assert.Single(tab.Children);
        Assert.Equal("%xOnce", tab.Children[0].Symbol);
        Assert.True(tab.Children[0].Foreign);
    }
}
